# =============================================================================
# pdp.R
# Partial Dependence Plot: how a model's predictions change as one feature
# varies across its range, averaged over the marginal distribution of all
# other features.
#
# Design principles (matching one_way.R):
#   - data.table for all aggregation - scales to 2M+ rows
#   - Native plotly output, identical dual-axis style to one_way
#   - Works with ANY model that implements a predict() S3/S4 method
#   - Pure functions - no side effects, no print() calls, no global mutation
#   - Fail fast with informative errors; return NULL on recoverable failures
#   - One function, one responsibility
# =============================================================================

# Suppress R CMD check NOTEs for data.table's non-standard evaluation.
# These dot-prefixed names are internal column names created within the
# package and never exist in the caller's data.
utils::globalVariables(c(
  ".bin",
  ".expo",
  ".pred",
  ".val",
  ".obs_col",
  ".expo_col",
  ".w",
  ".var",
  ".x_bin",
  ".split",
  "."
))

# -----------------------------------------------------------------------------
# PDP
# -----------------------------------------------------------------------------

#' Partial dependence plot for any predict()-compatible model
#'
#' For each bin of `var`, the function fixes that feature at the bin midpoint
#' (numeric) or bin label (categorical), runs `predict()` across a sample of
#' the full dataset, and averages the predictions. The result shows the
#' marginal effect of `var` on model output, stripped of all correlations with
#' other features.
#'
#' Alongside the PDP line the chart also shows:
#'   - Observed mean per bin (actual target, exposure-weighted)
#'   - Model average prediction per bin (in-sample, not PDP)
#'   - Global average observed and predicted reference lines
#'   - Yellow exposure bars (left axis) - identical style to `one_way()`
#'
#' @param data        A data frame or data.table. The full dataset used to
#'                    compute both the one-way actuals and the PDP sample.
#' @param var         `[character(1)]` Feature column to vary on the x-axis.
#' @param obs         `[character(1)]` Observed target column name.
#' @param model       A fitted model object. Standard R models (lm, glm,
#'                    xgb, ranger, tidymodels workflows, etc.) and H2O models
#'                    are supported automatically - no extra arguments needed.
#' @param exposure    `[character(1)]` Exposure weight column. If absent,
#'                    every row is given weight 1. Default `"exposure"`.
#' @param bins        `[integer(1)]` Number of bins for numeric `var`.
#'                    Default 10.
#' @param sample_size `[integer(1)]` Rows to sample for PDP computation.
#'                    Reducing this speeds up prediction at the cost of
#'                    accuracy. Default 10,000. The full dataset is always
#'                    used for the one-way actuals.
#' @param type_agg    `[character(1)]` Binning strategy: `"equal_exposure"`
#'                    (default) or `"equal_range"`.
#' @param model_name  `[character(1)]` Label shown in the plot legend.
#'                    Default `"model"`.
#' @param ret         `[character(1)]` `"plot"` (default) returns a plotly
#'                    object; `"data"` returns the aggregated data.table.
#'
#' @return A plotly object, or a data.table when `ret = "data"`, or `NULL`
#'         with a warning when the variable cannot be plotted.
#'
#' @examples
#' \dontrun{
#' m <- lm(mpg ~ wt + hp + cyl, data = mtcars)
#'
#' # Basic usage
#' pdp(mtcars, var = "wt", obs = "mpg", model = m)
#'
#' # GLM - predict() is dispatched automatically
#' g <- glm(vs ~ wt + hp, data = mtcars, family = binomial)
#' pdp(mtcars, var = "wt", obs = "vs", model = g)
#'
#' # Return aggregated data instead of a plot
#' pdp(mtcars, var = "wt", obs = "mpg", model = m, ret = "data")
#' }
#'
#' @seealso [one_way()] for observed-only one-way analysis.
#' @param data A `data.frame` or `data.table`.
#' @param ... Arguments passed to methods.
#' @export
pdp <- function(data, ...) UseMethod("pdp")

#' @rdname pdp
#' @method pdp default
#' @export
pdp.default <- function(
  data,
  var,
  obs,
  model,
  exposure = "exposure",
  bins = 10L,
  sample_size = 10000L,
  type_agg = c("equal_exposure", "equal_range"),
  model_name = "model",
  ret = c("plot", "data"),
  pre_process_fun = function(df) df,
  feat_eng_fun = function(df) df,
  post_process_fun = function(preds, df_raw) preds,
  ...
) {
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  # -- Validate -----------------------------------------------------------------
  pdp_validate(data, var, obs, exposure, bins, sample_size)

  # -- Coerce; always copy so the caller's object is never mutated -------------
  dt <- data.table::copy(data.table::as.data.table(data))

  # -- Apply pipeline for in-sample predictions --------------------------------
  df_eng <- as.data.frame(feat_eng_fun(pre_process_fun(as.data.frame(dt))))
  preds <- model_predict(model, df_eng)
  dt[, .pred := post_process_fun(preds, as.data.frame(dt))]

  # -- Resolve exposure ---------------------------------------------------------
  expo_col <- if (exposure %in% names(dt)) exposure else ".expo"
  if (expo_col == ".expo") {
    dt[, .expo := 1L]
  }

  # -- Guard: non-numeric columns with absurd cardinality -----------------------
  n_unique <- data.table::uniqueN(dt[[var]], na.rm = TRUE)
  if (n_unique > 500L && !is.numeric(dt[[var]])) {
    warning(sprintf(
      "pdp: '%s' has %d unique values (max 500 for non-numeric). Skipping.",
      var,
      n_unique
    ))
    return(NULL)
  }

  # -- Bin var across the full dataset ------------------------------------------
  bin_info <- compute_bins(dt[[var]], bins, type_agg)
  dt[, .bin := bin_info$labels]

  # -- Sample for PDP (raw snapshot, before obs is overwritten) ----------------
  # rep_set must hold raw feature values so compute_pdp can apply feat_eng once
  # cleanly per bin. Sampling happens after binning so .bin labels are present.
  n <- nrow(dt)
  samp_idx <- if (sample_size < n) {
    old_seed <- .Random.seed
    set.seed(2024L)
    idx <- sample(n, sample_size)
    .Random.seed <<- old_seed
    idx
  } else {
    seq_len(n)
  }
  rep_set <- data.table::copy(dt[samp_idx])

  # -- Align obs scale ---------------------------------------------------------
  # If feat_eng transforms the response (e.g. unitise), overwrite the obs
  # column in dt so that obs_mean and pred_mean are on the same scale.
  # Must use := so the update is by reference — [[<- on a data.table does not
  # modify in place and would leave the raw values visible to subsequent steps.
  if (is.data.frame(df_eng) && obs %in% names(df_eng)) {
    obs_eng <- df_eng[[obs]]
    dt[, (obs) := obs_eng]
  }

  # -- Aggregate one-way actuals + in-sample predictions ------------------------
  agg <- aggregate_pdp_oneway(dt, obs, expo_col)

  # -- Compute PDP ---------------------------------------------------------------
  pdp_agg <- compute_pdp(
    rep_set,
    var,
    bin_info,
    expo_col,
    model,
    pre_process_fun,
    feat_eng_fun,
    post_process_fun
  )

  # -- Merge one-way + PDP -------------------------------------------------------
  result <- merge(agg, pdp_agg, by = ".bin", all.x = TRUE)

  # -- Order x-axis --------------------------------------------------------------
  x_levels <- smart_level_order(unique(result$.bin))
  result[, .bin := factor(.bin, levels = x_levels)]
  data.table::setorder(result, .bin)
  result[, .bin := as.character(.bin)]

  # -- Global reference values ---------------------------------------------------
  w <- dt[[expo_col]]
  global_obs <- sum(dt[[obs]] * w, na.rm = TRUE) / sum(w, na.rm = TRUE)
  global_pred <- sum(dt$.pred * w, na.rm = TRUE) / sum(w, na.rm = TRUE)

  # -- Return --------------------------------------------------------------------
  if (ret == "data") {
    # Rename internal columns to user-friendly names
    data.table::setnames(result, ".bin", var)
    result[, global_obs := global_obs]
    result[, global_pred := global_pred]
    return(result[])
  }

  plot_pdp(result, var, obs, model_name, global_obs, global_pred)
}


# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

pdp_validate <- function(data, var, obs, exposure, bins, sample_size) {
  if (!is.data.frame(data) && !data.table::is.data.table(data)) {
    stop("`data` must be a data frame or data.table.", call. = FALSE)
  }
  if (length(var) == 1L && is.na(var)) {
    stop(
      "`var` is NA. Pass a column name, or call pdp() on a modelblueprint with `@x_original_inputs` set.",
      call. = FALSE
    )
  }
  assert_col_exists(data, var, "`var`")
  assert_col_exists(data, obs, "`obs`")

  if (!is.numeric(bins) || length(bins) != 1L || bins < 2L) {
    stop("`bins` must be a single integer >= 2.", call. = FALSE)
  }
  if (
    !is.numeric(sample_size) || length(sample_size) != 1L || sample_size < 1L
  ) {
    stop("`sample_size` must be a positive integer.", call. = FALSE)
  }
}

# Reuse assert_col_exists from one_way.R (same environment when both sourced)
if (!exists("assert_col_exists")) {
  assert_col_exists <- function(data, cols, arg_name) {
    missing_cols <- setdiff(cols, names(data))
    if (length(missing_cols) > 0L) {
      stop(
        sprintf(
          "%s column(s) not found in `data`: %s",
          arg_name,
          paste(missing_cols, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
}


# -----------------------------------------------------------------------------
# Prediction dispatch
# -----------------------------------------------------------------------------

#' Dispatch prediction to the correct backend
#'
#' Detects the model class and calls the appropriate prediction function:
#'   - H2O models  : converts newdata to an H2O frame, calls h2o.predict(),
#'                   extracts the result back to R, then removes the temp frame
#'   - All others  : calls predict(model, newdata) via S3/S4 dispatch and
#'                   coerces whatever shape is returned to a numeric vector
#'
#' @param model   A fitted model object (any class).
#' @param newdata A data.table or data.frame of predictor values.
#' @return        A numeric vector of predictions, one per row of newdata.
#' @keywords internal
model_predict <- function(model, newdata) {
  nd <- as.data.frame(newdata)

  if (
    inherits(
      model,
      c(
        "H2OModel",
        "H2OBinomialModel",
        "H2OMultinomialModel",
        "H2ORegressionModel",
        "H2OAutoML"
      )
    )
  ) {
    # H2O requires its own frame type and returns an H2O frame
    hf <- h2o::as.h2o(nd)
    raw <- as.data.frame(h2o::h2o.predict(model, hf))
    h2o::h2o.rm(hf) # clean up the temporary frame immediately

    # h2o.predict() column layout by family:
    #   regression / gaussian : "predict"           -> take col 1
    #   binomial              : "predict", "p0","p1" -> take "p1" (positive class prob)
    #   multinomial           : "predict", "C1","C2",... -> take col 2 (first class prob)
    # For binomial we always want the probability, not the class label in col 1.
    if ("p1" %in% names(raw)) {
      return(as.numeric(raw[["p1"]]))
    }
    return(as.numeric(raw[[1L]]))
  }

  # Standard S3/S4 predict - handles lm, glm, xgb, ranger, tidymodels, etc.
  # For glm, always predict on the response scale (probabilities for binomial,
  # fitted values for gaussian/poisson etc.) rather than the link scale.
  raw <- tryCatch(
    if (inherits(model, "glm")) {
      predict(model, newdata = nd, type = "response")
    } else {
      predict(model, newdata = nd)
    },
    error = function(e) {
      stop(
        sprintf(
          "pdp: predict() failed for model class '%s' - %s",
          paste(class(model), collapse = "/"),
          conditionMessage(e)
        ),
        call. = FALSE
      )
    }
  )

  # predict() can return a vector, matrix, data.frame, or named list -
  # extract the first column / element and coerce to numeric
  if (is.data.frame(raw) || is.matrix(raw)) {
    raw <- raw[, 1L]
  }
  as.numeric(raw)
}


# -----------------------------------------------------------------------------
# Binning
# -----------------------------------------------------------------------------

#' Compute bin labels and midpoints for a feature vector
#'
#' Returns a list with:
#'   - `labels`    : character vector (length = nrow of input), one label per row
#'   - `midpoints` : named numeric vector, bin label -> numeric midpoint
#'                   (NA for categorical bins)
#'   - `is_numeric`: logical, whether numeric binning was applied
#'
#' @keywords internal
compute_bins <- function(x, bins, type_agg) {
  is_cat <- inherits(x, c("factor", "character"))
  is_low_card <- !is_cat && data.table::uniqueN(x, na.rm = TRUE) <= bins

  if (is_cat || is_low_card) {
    # Categorical or low-cardinality: use value as-is
    labels <- as.character(x)
    labels[is.na(x)] <- "NA"
    return(list(labels = labels, midpoints = NULL, is_numeric = FALSE))
  }

  # Numeric binning - reuse bin_equal_exposure / bin_equal_range from one_way.R
  v_sorted <- sort(x[!is.na(x)])
  bin_fn <- if (type_agg == "equal_range") {
    bin_equal_range
  } else {
    bin_equal_exposure
  }
  cut_result <- suppressWarnings(bin_fn(v_sorted, bins))

  # Map cut labels back to original row positions (identical to apply_binning)
  raw_labels <- rep(NA_character_, length(x))
  non_na_idx <- which(!is.na(x))
  sorted_non_na_idx <- non_na_idx[order(x[non_na_idx])]
  raw_labels[sorted_non_na_idx] <- as.character(cut_result)
  raw_labels[is.na(x)] <- "NA"

  # Compute midpoints from interval labels - used to fix the feature for PDP.
  # cut() produces labels like "[1.5,11.9]" or "(1.5,11.9]".
  # Two simple sub() calls are safer than a character class for brackets
  # because R's TRE engine handles [\]] ambiguously inside character classes.
  lvl_chars <- levels(cut_result)
  midpoints <- vapply(
    lvl_chars,
    function(lbl) {
      inner <- sub("^[[(]", "", lbl) # strip leading "[" or "("
      inner <- sub("[])]$", "", inner) # strip trailing "]" or ")"
      nums <- suppressWarnings(as.numeric(strsplit(inner, ",")[[1L]]))
      if (length(nums) == 2L && all(is.finite(nums))) mean(nums) else NA_real_
    },
    numeric(1L)
  )
  names(midpoints) <- lvl_chars

  list(labels = raw_labels, midpoints = midpoints, is_numeric = TRUE)
}


# -----------------------------------------------------------------------------
# One-way aggregation (actuals + in-sample predictions)
# -----------------------------------------------------------------------------

#' Aggregate observed and in-sample predicted values per bin
#'
#' Operates on `dt` which must already have columns `.bin`, `.pred`,
#' the obs column, and the exposure column.
#'
#' @return data.table with columns: .bin, obs_mean, pred_mean, exposure
#' @keywords internal
aggregate_pdp_oneway <- function(dt, obs, expo_col) {
  # Capture column name strings in dot-prefixed locals so they are resolved
  # as strings in the enclosing function scope, not as column lookups inside
  # the data.table j expression. Without this, if obs = "obs" and there is a
  # column named "obs", data.table resolves `obs` to that column vector and
  # .SD[[obs]] receives a vector instead of a string, causing an error.
  .obs_col <- obs
  .expo_col <- expo_col

  dt[,
    {
      w <- .SD[[.expo_col]]
      w_total <- sum(w, na.rm = TRUE)
      obs_mean <- sum(.SD[[.obs_col]] * w, na.rm = TRUE) / w_total
      prd_mean <- sum(.SD[[".pred"]] * w, na.rm = TRUE) / w_total
      list(
        obs_mean = obs_mean,
        pred_mean = prd_mean,
        exposure = w_total
      )
    },
    by = .bin,
    .SDcols = c(.obs_col, .expo_col, ".pred")
  ]
}


# -----------------------------------------------------------------------------
# PDP computation
# -----------------------------------------------------------------------------

#' Compute PDP values for each bin
#'
#' For each bin, fixes the feature at its midpoint (numeric) or label
#' (categorical), runs predictions across the full sample, and returns the
#' mean prediction.
#'
#' @return data.table with columns: .bin, pdp_mean
#' @keywords internal
compute_pdp <- function(
  rep_set,
  var,
  bin_info,
  expo_col,
  model,
  pre_process_fun,
  feat_eng_fun,
  post_process_fun
) {
  # Build bins_to_use from the OBSERVED .bin labels in rep_set - these are
  # guaranteed to match agg$.bin exactly because both come from bin_info$labels.
  # Using names(bin_info$midpoints) instead caused subtle label mismatches
  # (spacing, rounding) that left pdp_mean as NA after the merge.
  observed_bins <- unique(rep_set$.bin[rep_set$.bin != "NA"])

  bins_to_use <- if (bin_info$is_numeric) {
    # Look up the midpoint for each observed label via the midpoints lookup.
    # The lookup keys are cut() level labels; observed labels are the same
    # strings so the match is exact.
    midpoints_matched <- bin_info$midpoints[observed_bins]
    valid <- observed_bins[!is.na(midpoints_matched)]
    data.table::data.table(
      .bin = valid,
      .val = bin_info$midpoints[valid]
    )
  } else {
    data.table::data.table(
      .bin = observed_bins,
      .val = NA_real_
    )
  }

  # Pre-allocate result - avoids growing a list in a loop
  n_bins <- nrow(bins_to_use)
  results <- vector("list", n_bins)

  for (i in seq_len(n_bins)) {
    bin_label <- bins_to_use$.bin[i]
    bin_val <- bins_to_use$.val[i]

    # Copy the sample and fix the feature - data.table copy is shallow + COW
    nd <- data.table::copy(rep_set)
    nd[[var]] <- if (bin_info$is_numeric) {
      rep(bin_val, nrow(nd))
    } else {
      # Preserve original column type (factor, character, integer)
      coerce_to_original(rep_set[[var]], bin_label)
    }

    nd_eng <- as.data.frame(feat_eng_fun(pre_process_fun(as.data.frame(nd))))
    preds <- model_predict(model, nd_eng)
    preds <- post_process_fun(preds, as.data.frame(nd))
    results[[i]] <- data.table::data.table(
      .bin = bin_label,
      pdp_mean = mean(preds, na.rm = TRUE)
    )
  }

  if (length(results) == 0L) {
    return(data.table::data.table(.bin = character(0L), pdp_mean = numeric(0L)))
  }
  data.table::rbindlist(results)
}

#' Coerce a bin label back to the original column type
#' @keywords internal
coerce_to_original <- function(original_vec, label) {
  cls <- class(original_vec)[1L]
  val <- switch(
    cls,
    factor = factor(label, levels = levels(original_vec)),
    integer = suppressWarnings(as.integer(label)),
    numeric = suppressWarnings(as.numeric(label)),
    double = suppressWarnings(as.numeric(label)),
    label
  )
  rep(val, length(original_vec))
}


# -----------------------------------------------------------------------------
# Plot
# -----------------------------------------------------------------------------

#' Render the PDP chart
#'
#' Produces a dual-axis plotly chart that exactly matches one_way() styling:
#'   - Left axis  : yellow exposure bars
#'   - Right axis : observed mean (purple), avg predicted (blue), PDP (teal)
#'   - Global reference lines for both observed and predicted means
#'
#' @keywords internal
plot_pdp <- function(result, var, obs, model_name, global_obs, global_pred) {
  x_levels <- smart_level_order(unique(result$.bin))
  df <- as.data.frame(result)

  # Colour scheme - purple for observed (matches one_way lead colour),
  # Paired blues for predicted/PDP
  col_obs <- "#9900cc"
  pal <- RColorBrewer::brewer.pal(3L, "Paired")
  col_pred <- pal[2L] # blue
  col_pdp <- pal[4L] # darker blue / teal

  p <- plotly::plot_ly(df)

  # -- Observed mean line -------------------------------------------------------
  p <- plotly::add_trace(
    p,
    x = ~.bin,
    y = ~obs_mean,
    yaxis = "y2",
    type = "scatter",
    mode = "lines+markers",
    name = obs,
    line = list(color = col_obs),
    marker = list(color = col_obs, symbol = "square"),
    hoverinfo = "text",
    hovertext = paste0(obs, ": ", sig_dig(df$obs_mean, 7L))
  )

  # -- Observed grand-mean reference --------------------------------------------
  p <- plotly::add_trace(
    p,
    x = x_levels,
    y = rep(global_obs, length(x_levels)),
    yaxis = "y2",
    type = "scatter",
    mode = "lines",
    name = paste(obs, "Mean"),
    line = list(color = col_obs),
    hoverinfo = "text",
    hovertext = paste0("Mean ", obs, ": ", sig_dig(global_obs, 7L))
  )

  # -- In-sample average predicted line -----------------------------------------
  err_pred <- round(
    (df$pred_mean - df$obs_mean) / df$obs_mean * 100,
    1L
  )
  p <- plotly::add_trace(
    p,
    x = ~.bin,
    y = ~pred_mean,
    yaxis = "y2",
    type = "scatter",
    mode = "lines+markers",
    name = paste0("avg_pred_", model_name),
    line = list(color = col_pred),
    marker = list(color = col_pred, symbol = "triangle-up", size = 10L),
    hoverinfo = "text",
    hovertext = paste0(
      "avg_pred_",
      model_name,
      ": ",
      sig_dig(df$pred_mean, 7L),
      ", err: ",
      err_pred,
      "%"
    )
  )

  # -- In-sample predicted grand-mean reference ----------------------------------
  p <- plotly::add_trace(
    p,
    x = x_levels,
    y = rep(global_pred, length(x_levels)),
    yaxis = "y2",
    type = "scatter",
    mode = "lines",
    name = paste0("avg_pred_", model_name, " Mean"),
    line = list(color = col_pred),
    hoverinfo = "text",
    hovertext = paste0(
      "Mean avg_pred_",
      model_name,
      ": ",
      sig_dig(global_pred, 7L)
    )
  )

  # -- PDP line -----------------------------------------------------------------
  # PDP deviation expressed as % of global predicted mean
  pdp_dev <- round(
    (df$pdp_mean - global_pred) / global_pred * 100,
    1L
  )
  p <- plotly::add_trace(
    p,
    x = ~.bin,
    y = ~pdp_mean,
    yaxis = "y2",
    type = "scatter",
    mode = "lines+markers",
    name = paste0("pdp_", model_name),
    line = list(color = col_pdp),
    marker = list(color = col_pdp, symbol = "circle", size = 10L),
    hoverinfo = "text",
    hovertext = paste0(
      "pdp_",
      model_name,
      ": ",
      sig_dig(df$pdp_mean, 7L),
      ", vs global avg: ",
      pdp_dev,
      "%"
    )
  )

  # -- Yellow exposure bars (left axis) - identical to one_way() ----------------
  p <- plotly::add_trace(
    p,
    x = ~.bin,
    y = ~exposure,
    yaxis = "y",
    type = "bar",
    orientation = "v",
    name = "Exposure",
    marker = list(color = "#ffff00"),
    hoverinfo = "text",
    hovertext = paste0("Exposure: ", df$.bin, " = ", sig_dig(df$exposure, 7L))
  )

  # -- Layout - identical to one_way() ------------------------------------------
  p %>%
    plotly::layout(
      xaxis = list(
        title = var,
        categoryorder = "array",
        categoryarray = x_levels
      ),
      yaxis = list(title = "Exposure", showgrid = FALSE, autorange = TRUE),
      yaxis2 = list(
        overlaying = "y",
        side = "right",
        showgrid = TRUE,
        autorange = TRUE,
        title = "Observed / Predicted"
      ),
      legend = list(x = 1.15, y = 0.5),
      margin = list(t = 25, b = 100, l = 50, r = 50),
      hovermode = "x",
      plot_bgcolor = "rgba(0,0,0,0)",
      paper_bgcolor = "rgba(0,0,0,0)"
    )
}


# -----------------------------------------------------------------------------
# Utilities (duplicated from one_way.R for standalone use)
# -----------------------------------------------------------------------------

# smart_level_order, sig_dig, bin_equal_exposure, bin_equal_range are shared
# with one_way.R. When both files are sourced they share a common definition.
# These fallbacks ensure pdp.R works standalone if one_way.R is not loaded.

if (!exists("smart_level_order")) {
  smart_level_order <- function(x) {
    if (length(x) == 0L) {
      return(x)
    }
    leading <- suppressWarnings(as.numeric(
      sub("^[\\[\\(]?(-?[0-9]*\\.?[0-9]+).*", "\\1", trimws(x), perl = TRUE)
    ))
    is_num <- !is.na(leading)
    na_label <- x[x == "NA"]
    c(
      x[is_num][order(leading[is_num])],
      sort(x[!is_num & x != "NA"]),
      na_label
    )
  }
}

if (!exists("sig_dig")) {
  sig_dig <- function(x, n = 7L) {
    formatC(signif(x, digits = n), digits = n, format = "fg", flag = "#")
  }
}

if (!exists("bin_equal_exposure")) {
  bin_equal_exposure <- function(x_sorted, bins) {
    n <- length(x_sorted)
    idx <- unique(as.integer(seq(n / bins, n, length.out = bins)))
    breaks <- signif(c(x_sorted[1L], x_sorted[idx]), 7L)
    breaks <- unique(breaks)
    breaks[1L] <- min(x_sorted)
    breaks[length(breaks)] <- max(x_sorted)
    cut(x_sorted, breaks = breaks, include.lowest = TRUE, dig.lab = 7L)
  }
}

if (!exists("bin_equal_range")) {
  bin_equal_range <- function(x, bins) {
    rng <- range(x, na.rm = TRUE)
    spread <- diff(rng)
    mag <- if (is.finite(spread) && spread > 0) {
      floor(log10(spread / bins))
    } else {
      0L
    }
    decimals <- if (mag < 0L) 2L - mag else 0L
    breaks <- round(seq(rng[1L], rng[2L], length.out = bins + 1L), decimals)
    cut(
      x,
      breaks = unique(breaks),
      include.lowest = TRUE,
      dig.lab = max(7L, decimals + 3L)
    )
  }
}
