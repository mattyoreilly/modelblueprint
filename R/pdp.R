# =============================================================================
# pdp.R
# Partial Dependence Plot: how a model's predictions change as one feature
# varies across its range, averaged over the marginal distribution of all
# other features.
# =============================================================================



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
#' @param pre_process_fun  `function(df) -> df` applied to the data before
#'   feature engineering. Default is the identity function.
#' @param feat_eng_fun     `function(df) -> df` (or matrix) applied after
#'   pre-processing to produce the model input. Default is the identity
#'   function.
#' @param post_process_fun `function(preds, df_raw) -> numeric` applied to raw
#'   model predictions. Default is the identity function.
#' @param seed        `[integer(1)]` Seed for the PDP row sample, applied via
#'                    [withr::with_seed()] so the global RNG stream is left
#'                    undisturbed. Default `2024L`.
#' @param verbose     `[logical(1)]` Announce the variable being computed?
#'                    Default `FALSE`.
#'
#' @return A plotly object, or a data.table when `ret = "data"`, or `NULL`
#'         with a warning when the variable cannot be plotted.
#'
#' @examples
#' \donttest{
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
  seed = 2024L,
  verbose = FALSE,
  ...
) {
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  # -- Validate -----------------------------------------------------------------
  pdp_validate(data, var, obs, exposure, bins, sample_size)

  # -- Coerce; always copy so the caller's object is never mutated -------------
  dt <- data.table::copy(data.table::as.data.table(data))

  if (isTRUE(verbose)) {
    cli::cli_alert_info("Calculating pdp for {.var {var}}")
  }

  # -- Apply pipeline for in-sample predictions --------------------------------
  df_pp  <- call_pipeline_fun(pre_process_fun, "pre_process_fun", as.data.frame(dt))
  df_eng <- as.data.frame(call_pipeline_fun(feat_eng_fun, "feat_eng_fun", df_pp))
  preds  <- model_predict(model, df_eng)
  dt[, .pred := call_pipeline_fun(post_process_fun, "post_process_fun", preds, as.data.frame(dt))]

  # -- Resolve exposure ---------------------------------------------------------
  expo_col <- if (exposure %in% names(dt)) exposure else ".expo"
  if (expo_col == ".expo") {
    dt[, .expo := 1L]
  }

  # -- Guard: non-numeric columns with absurd cardinality -----------------------
  n_unique <- data.table::uniqueN(dt[[var]], na.rm = TRUE)
  if (n_unique > 500L && !is.numeric(dt[[var]])) {
    cli::cli_warn(
      "{.arg {var}} has {n_unique} unique values (max 500 for non-numeric). Skipping."
    )
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
    # withr::with_seed() runs the draw with a fixed seed and restores the
    # caller's RNG state afterwards, so results are reproducible without
    # disturbing the global stream.
    withr::with_seed(seed, sample(n, sample_size))
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
  # Pass all bins from the full-data agg so the PDP is computed for every bin
  # that has exposure, not just those that happened to land in rep_set.
  # Without this, low-exposure bins missing from the sample get NA pdp_mean
  # after the merge and the PDP line disappears at those points.
  all_bins <- unique(agg$.bin[agg$.bin != "NA"])
  pdp_agg <- compute_pdp(
    rep_set,
    var,
    bin_info,
    all_bins,
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
  # Denominators count only the exposure of rows with a non-missing value,
  # mirroring the per-bin means in aggregate_pdp_oneway().
  w <- dt[[expo_col]]
  global_obs <- sum(dt[[obs]] * w, na.rm = TRUE) /
    sum(w[!is.na(dt[[obs]])], na.rm = TRUE)
  global_pred <- sum(dt$.pred * w, na.rm = TRUE) /
    sum(w[!is.na(dt$.pred)], na.rm = TRUE)

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

pdp_validate <- function(data, var, obs, exposure, bins, sample_size) {
  if (!is.data.frame(data) && !data.table::is.data.table(data)) {
    cli::cli_abort("{.arg data} must be a data frame or data.table.")
  }
  if (length(var) == 1L && is.na(var)) {
    cli::cli_abort(
      "{.arg var} is NA. Pass a column name, or call {.fn pdp} on a modelblueprint with {.arg @x_original_inputs} set."
    )
  }
  assert_col_exists(data, var, "`var`")
  assert_col_exists(data, obs, "`obs`")

  if (!is.numeric(bins) || length(bins) != 1L || bins < 2L) {
    cli::cli_abort("{.arg bins} must be a single integer >= 2.")
  }
  if (
    !is.numeric(sample_size) || length(sample_size) != 1L || sample_size < 1L
  ) {
    cli::cli_abort("{.arg sample_size} must be a positive integer.")
  }
}

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
  # A plain data.frame is passed straight through; only coerce when needed
  # (e.g. a data.table, which some predict() methods mishandle). Callers in the
  # PDP/SHAP batch paths already hand us a plain data.frame, so this avoids
  # re-copying a large frame on every prediction.
  nd <- if (is.data.frame(newdata) && !data.table::is.data.table(newdata)) {
    newdata
  } else {
    as.data.frame(newdata)
  }

  if (is_h2o_model(model)) {
    # Multinomial has no single probability column to reduce to, and column 1
    # of h2o.predict() is the class *label* — as.numeric() on it would return
    # meaningless factor level codes rather than probabilities.
    if (inherits(model, "H2OMultinomialModel")) {
      cli::cli_abort(c(
        "H2O multinomial models are not supported.",
        i = paste0(
          "modelblueprint diagnostics need a single numeric prediction per ",
          "row; a multinomial model returns one probability per class."
        )
      ))
    }

    # H2O requires its own frame type and returns an H2O frame
    hf <- h2o::as.h2o(nd)
    raw <- as.data.frame(h2o::h2o.predict(model, hf))
    h2o::h2o.rm(hf) # clean up the temporary frame immediately

    # h2o.predict() column layout by family:
    #   regression / gaussian : "predict"            -> take col 1
    #   binomial              : "predict","p0","p1"  -> take "p1" (positive class prob)
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
      cli::cli_abort(c(
        "{.fn predict} failed for model class {.val {paste(class(model), collapse = '/')}}.",
        x = conditionMessage(e)
      ))
    }
  )

  # predict() can return a vector, matrix, data.frame, or named list -
  # extract the first column / element and coerce to numeric
  if (is.data.frame(raw) || is.matrix(raw)) {
    raw <- raw[, 1L]
  }
  as.numeric(raw)
}

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

  # Numeric binning - shared binning module (binning.R) handles strategy
  # selection and remapping labels back onto the original row order.
  binned <- bin_numeric(x, bins, type_agg)
  cut_result <- binned$cut
  raw_labels <- binned$labels
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

#' Aggregate observed and in-sample predicted values per bin
#'
#' Operates on `dt` which must already have columns `.bin`, `.pred`,
#' the obs column, and the exposure column.
#'
#' @return data.table with columns: .bin, obs_mean, pred_mean, exposure
#' @keywords internal
aggregate_pdp_oneway <- function(dt, obs, expo_col) {
  # Pre-weight obs and prediction by exposure, then take plain grouped sums so
  # data.table's GForce optimisation applies (a per-group division inside j
  # would disable it). Divide by the grouped weight afterwards. The weighted
  # columns are computed in plain R and added with set() — referencing dynamic
  # column names via dt[[...]] inside a := expression misresolves under
  # data.table's NSE. Dot-prefixed names cannot collide with a user column.
  w <- dt[[expo_col]]
  data.table::set(dt, j = ".wobs", value = dt[[obs]] * w)
  data.table::set(dt, j = ".wpred", value = dt[[".pred"]] * w)
  # Per-column denominators: count only the exposure of rows where the value
  # is non-missing — the numerator drops NA rows via na.rm, so dividing by
  # the full bin exposure would deflate the mean wherever the target has NAs.
  data.table::set(dt, j = ".wobs_den", value = w * !is.na(dt[[obs]]))
  data.table::set(dt, j = ".wpred_den", value = w * !is.na(dt[[".pred"]]))

  agg <- dt[,
    lapply(.SD, sum, na.rm = TRUE),
    by = .bin,
    .SDcols = c(".wobs", ".wpred", ".wobs_den", ".wpred_den", expo_col)
  ]
  data.table::setnames(
    agg,
    c(".wobs", ".wpred", expo_col),
    c("obs_mean", "pred_mean", "exposure")
  )
  agg[, obs_mean := obs_mean / .wobs_den]
  agg[, pred_mean := pred_mean / .wpred_den]
  agg[, c(".wobs_den", ".wpred_den") := NULL]
  agg[]
}

#' Compute PDP values for each bin (batch approach)
#'
#' Replicates the sample once per bin into a single large data.table, stamps
#' each block with the corresponding bin value, then calls predict() exactly
#' once. Group-averaging over blocks gives the PDP mean per bin.
#'
#' For models with per-call overhead (H2O HTTP round-trips, remote endpoints,
#' XGBoost DMatrix construction) this is typically 5-20x faster than calling
#' predict() once per bin in a loop.
#'
#' Memory cost: sample_size * n_bins rows. At 10,000 rows x 15 bins that is
#' 150,000 rows — well within reason for a typical dataset.
#'
#' @return data.table with columns: .bin, pdp_mean
#' @keywords internal
compute_pdp <- function(
  rep_set,
  var,
  bin_info,
  all_bins,
  expo_col,
  model,
  pre_process_fun,
  feat_eng_fun,
  post_process_fun
) {
  # all_bins comes from the full-dataset agg, so every bin with exposure is
  # covered even if some bins were not sampled into rep_set.

  bins_to_use <- if (bin_info$is_numeric) {
    # Look up midpoints for every bin from the full dataset.
    # all_bins labels are the same cut() strings as names(bin_info$midpoints),
    # so the named lookup is exact.
    midpoints_matched <- bin_info$midpoints[all_bins]
    valid <- all_bins[!is.na(midpoints_matched)]
    data.table::data.table(
      .bin = valid,
      .val = bin_info$midpoints[valid]
    )
  } else {
    data.table::data.table(
      .bin = all_bins,
      .val = NA_real_
    )
  }

  n_bins <- nrow(bins_to_use)
  if (n_bins == 0L) {
    return(data.table::data.table(.bin = character(0L), pdp_mean = numeric(0L)))
  }

  n_samp <- nrow(rep_set)

  # --- Batch replication -------------------------------------------------------
  # Stack n_bins copies of rep_set into one frame. data.table's integer
  # subsetting with rep() is the cheapest path — no list allocation needed.
  big <- rep_set[rep(seq_len(.N), times = n_bins)]

  # Overwrite the feature column: each block of n_samp rows gets the value for
  # its corresponding bin (midpoint for numeric; label cast to original type
  # for categorical). Use data.table::set() rather than `big[[var]] <- ...`,
  # which would shallow-copy the whole (tall) frame on assignment.
  new_vals <- if (bin_info$is_numeric) {
    rep(bins_to_use$.val, each = n_samp)
  } else {
    bin_vals <- rep(bins_to_use$.bin, each = n_samp)
    # Preserve the column's original class so feat_eng_fun sees the same type
    cls <- class(rep_set[[var]])[1L]
    switch(
      cls,
      factor  = factor(bin_vals, levels = levels(rep_set[[var]])),
      ordered = ordered(bin_vals, levels = levels(rep_set[[var]])),
      logical = as.logical(bin_vals),
      integer = suppressWarnings(as.integer(bin_vals)),
      numeric = suppressWarnings(as.numeric(bin_vals)),
      double  = suppressWarnings(as.numeric(bin_vals)),
      bin_vals  # character / default
    )
  }
  data.table::set(big, j = var, value = new_vals)

  # --- Single predict() call ---------------------------------------------------
  # big intentionally contains no extra tracking columns — feat_eng_fun and
  # pre_process_fun see exactly the same column layout as in the sequential
  # path, just over a taller frame.
  #
  # setDF() converts the (internal, soon-discarded) data.table to a data.frame
  # *by reference* — no copy of the tall frame, unlike as.data.frame(). The
  # as.data.frame() wrap around feat_eng_fun's output is dropped because
  # model_predict() already coerces non-data.frame input (e.g. a matrix).
  big_df  <- data.table::setDF(big)
  big_pp  <- call_pipeline_fun(pre_process_fun, "pre_process_fun", big_df)
  big_eng <- call_pipeline_fun(feat_eng_fun, "feat_eng_fun", big_pp)
  preds   <- model_predict(model, big_eng)
  preds   <- call_pipeline_fun(post_process_fun, "post_process_fun", preds, big_df)

  # --- Group-average by bin block ---------------------------------------------
  # Build a lightweight tracking table rather than adding a column to `big`
  # (avoids mutating the frame that was just passed to the pipeline).
  bin_groups <- rep(seq_len(n_bins), each = n_samp)
  out <- data.table::data.table(.bin_group = bin_groups, .pdp_pred = preds)[
    ,
    .(pdp_mean = mean(.pdp_pred, na.rm = TRUE)),
    by = .bin_group
  ]
  out[, .bin      := bins_to_use$.bin[.bin_group]]
  out[, .bin_group := NULL]
  out[]
}

#' Render the PDP chart
#'
#' Produces a dual-axis plotly chart that exactly matches one_way() styling:
#'   - Left axis  : yellow exposure bars
#'   - Right axis : observed mean (purple), avg predicted (blue), PDP (teal)
#'   - Global reference lines for both observed and predicted means
#'
#' @keywords internal
plot_pdp <- function(result, var, obs, model_name, global_obs, global_pred) {
  # Drop the "NA" bin from the plot: it has no PDP value (can't fix a feature
  # at NA) and smart_level_order puts it last, making the PDP line appear to
  # stop one bar early. The "NA" bin is still present in ret = "data" output.
  result <- result[result$.bin != "NA"]
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
  # pct_diff() blanks the percentage when the observed mean is 0 or missing.
  err_pred <- pct_diff(df$pred_mean, df$obs_mean)
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
      ifelse(nzchar(err_pred), paste0(", err: ", err_pred), "")
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
  # PDP deviation expressed as % of global predicted mean; blanked by
  # pct_diff() when that mean is 0 or missing.
  pdp_dev <- pct_diff(df$pdp_mean, global_pred)
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
      ifelse(nzchar(pdp_dev), paste0(", vs global avg: ", pdp_dev), "")
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
  p$sizingPolicy$defaultHeight <- 800
  p |>
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
