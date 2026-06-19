# =============================================================================
# shap.R
# SHAP (SHapley Additive exPlanations)  - permutation-based, no external dep.
#
# Algorithm: for each feature j, run `nsim` random permutations. In each
# permutation, the features that appear *before* j take actual values; the
# rest take values from a randomly drawn background row. The difference
# between predictions "with j" vs "without j" (i.e. j also swapped to
# background) is j's marginal contribution for that permutation. Averaging
# over permutations gives the Shapley value.
#
# Prediction batching mirrors compute_pdp() in pdp.R: all n*nsim with/without
# rows for one feature are stacked into a single data.frame and passed to
# model_predict() in one call, so per-call overhead (H2O HTTP, XGBoost
# DMatrix) is paid only once per feature.
#
# Reuses from the package:
#   model_predict()    - pdp.R: H2O/XGBoost/GLM dispatch
#   compute_bins()     - pdp.R: equal-exposure / equal-range numeric binning
#   smart_level_order()  - one_way.R: chronological / interval label sort
#   sig_dig()          - one_way.R: hover text formatting
# =============================================================================

utils::globalVariables(c(
  ".bin",
  ".shap",
  ".expo_shap"
))


# =============================================================================
# shap()  - S3 generic
# =============================================================================

#' SHAP Feature Importance and Dependence Plots
#'
#' Computes approximate SHAP (SHapley Additive exPlanations) values using a
#' built-in permutation algorithm and returns either a **feature importance**
#' chart (signed mean SHAP per feature  - purple = increases prediction, blue =
#' decreases prediction, sorted by magnitude) or a **dependence** plot (mean
#' SHAP per bin alongside exposure bars). Both plots use the same dual-axis
#' Plotly style as [one_way()] and [pdp()].
#'
#' The algorithm is model-agnostic: it works with any model that has a
#' `predict()` method, including GLMs, XGBoost, randomForest, and H2O models.
#' No external packages beyond the modelblueprint dependencies are required.
#'
#' @param data A `data.frame`, `data.table`, or `modelblueprint`.
#' @param ...  Arguments passed to methods.
#'
#' @return A plotly object, a data.table (when `ret = "data"`), or a named
#'   list of plotly objects when `type = "dependence"` and `vars` has more
#'   than one element.
#'
#' @seealso [one_way()], [pdp()]
#' @export
shap <- function(data, ...) UseMethod("shap")


#' @rdname shap
#' @method shap default
#'
#' @param data             A `data.frame` or `data.table`. Must contain the
#'                         columns named in `vars` and, optionally, `exposure`.
#' @param model            A fitted model object.
#' @param vars             `[character]` Feature column names for which SHAP
#'                         values are computed.
#' @param exposure         `[character(1)]` Exposure weight column. If the
#'                         column is absent, every row is given weight 1.
#'                         Default `"exposure"`. Used only in the dependence
#'                         plot (exposure bars and weighted mean SHAP line).
#' @param type             `[character(1)]` Plot type: `"importance"` (default)
#'                         returns a signed horizontal bar chart of mean SHAP
#'                         per feature (purple = positive effect, blue =
#'                         negative effect, sorted by |SHAP| magnitude);
#'                         `"dependence"` returns a dual-axis chart (exposure
#'                         bars + mean SHAP per bin) for each variable in
#'                         `vars`.
#' @param nsim             `[integer(1)]` Number of random permutations per
#'                         observation. Higher values give more stable SHAP
#'                         estimates at the cost of compute time. Default
#'                         `50L`.
#' @param sample_size      `[integer(1)]` Rows sampled from `data` for SHAP
#'                         computation. Default `500L`. Seeded at 2024 for
#'                         reproducibility.
#' @param bins             `[integer(1)]` Number of bins for the dependence
#'                         plot x-axis. Default `10L`.
#' @param type_agg         `[character(1)]` Binning strategy for the
#'                         dependence plot: `"equal_exposure"` (default) or
#'                         `"equal_range"`.
#' @param ret              `[character(1)]` `"plot"` (default) or `"data"`.
#'                         `"data"` returns a data.table with one SHAP column
#'                         per feature in `vars`.
#' @param model_name       `[character(1)]` Label shown in plot titles.
#'                         Default `"model"`.
#' @param pre_process_fun  `function(df) -> df` applied before `feat_eng_fun`.
#'                         Default is the identity function.
#' @param feat_eng_fun     `function(df) -> df` (or matrix) that produces the
#'                         model input. Default is the identity function.
#' @param post_process_fun `function(preds, df_raw) -> numeric` applied to raw
#'                         model predictions. Default is the identity function.
#' @param seed             `[integer(1)]` Seed for the row sample and the
#'                         internal SHAP permutations, applied via
#'                         [withr::with_seed()] so the global RNG stream is left
#'                         undisturbed and results are reproducible. Default
#'                         `2024L`.
#' @param ...              Unused.
#'
#' @examples
#' \donttest{
#' m <- lm(mpg ~ wt + hp + cyl + am, data = mtcars)
#'
#' # Feature importance (mean |SHAP|)
#' shap(mtcars, model = m, vars = c("wt", "hp", "cyl", "am"),
#'      type = "importance", nsim = 10L, sample_size = 32L)
#'
#' # Dependence plot for one feature
#' shap(mtcars, model = m, vars = "wt",
#'      type = "dependence", nsim = 10L, sample_size = 32L)
#' }
#'
#' @export
shap.default <- function(
  data,
  model,
  vars,
  exposure         = "exposure",
  type             = c("importance", "dependence"),
  nsim             = 50L,
  sample_size      = 500L,
  bins             = 10L,
  type_agg         = c("equal_exposure", "equal_range"),
  ret              = c("plot", "data"),
  model_name       = "model",
  pre_process_fun  = function(df) df,
  feat_eng_fun     = function(df) df,
  post_process_fun = function(preds, df_raw) preds,
  seed             = 2024L,
  ...
) {
  type     <- match.arg(type)
  type_agg <- match.arg(type_agg)
  ret      <- match.arg(ret)

  if (!is.data.frame(data) && !data.table::is.data.table(data)) {
    cli::cli_abort("{.arg data} must be a data frame or data.table.")
  }
  if (missing(vars) || length(vars) == 0L) {
    cli::cli_abort(
      "{.arg vars} must be a non-empty character vector of feature names."
    )
  }
  missing_vars <- setdiff(vars, names(data))
  if (length(missing_vars) > 0L) {
    cli::cli_abort(
      "Column(s) not found in {.arg data}: {.val {missing_vars}}"
    )
  }

  # -- Resolve exposure ----------------------------------------------------------
  dt_full <- data.table::as.data.table(data)
  expo_col <- if (exposure %in% names(dt_full)) exposure else ".expo"
  if (expo_col == ".expo") {
    dt_full[, .expo := 1L]
  }

  # -- Sample rows to explain ----------------------------------------------------
  # withr::with_seed() draws with a fixed seed and restores the caller's RNG
  # state afterwards, so the sample is reproducible without disturbing the
  # global stream.
  n <- nrow(dt_full)
  idx_sample <- withr::with_seed(
    seed,
    sample(n, min(as.integer(sample_size), n))
  )

  dt_sample <- dt_full[idx_sample]
  # Pass the full data frame  - the model may need columns outside `vars`
  # (e.g. an lm trained on x_num + x_int when vars = "x_num"). compute_shap
  # only permutes the `vars` columns; all other columns keep their actual values.
  X_full    <- as.data.frame(dt_sample)
  expo_vals <- dt_sample[[expo_col]]

  # -- Compute SHAP values -------------------------------------------------------
  cli::cli_alert_info(
    "Computing SHAP values: {length(vars)} feature(s), \\
    {nrow(X_full)} row(s), {nsim} permutation(s) each."
  )

  # compute_shap() draws random permutations and background rows internally, so
  # run it under the same seed to make the SHAP values fully reproducible.
  shap_df <- withr::with_seed(
    seed,
    compute_shap(
      X_full           = X_full,
      model            = model,
      vars             = vars,
      nsim             = as.integer(nsim),
      pre_process_fun  = pre_process_fun,
      feat_eng_fun     = feat_eng_fun,
      post_process_fun = post_process_fun
    )
  )

  # -- Return data ---------------------------------------------------------------
  if (ret == "data") {
    return(data.table::as.data.table(shap_df))
  }

  # -- Plot: importance ----------------------------------------------------------
  if (type == "importance") {
    imp <- data.frame(
      feature       = vars,
      mean_shap     = vapply(vars, function(v) mean(shap_df[[v]], na.rm = TRUE), numeric(1L)),
      mean_abs_shap = vapply(vars, function(v) mean(abs(shap_df[[v]]), na.rm = TRUE), numeric(1L)),
      stringsAsFactors = FALSE
    )
    return(plot_shap_importance(imp, model_name))
  }

  # -- Plot: dependence ----------------------------------------------------------
  # One plot per feature; return single object when only one var requested.
  plots <- stats::setNames(
    lapply(vars, function(v) {
      agg <- aggregate_shap_bin(
        feat_vals = X_full[[v]],
        shap_vals = shap_df[[v]],
        expo_vals = expo_vals,
        bins      = bins,
        type_agg  = type_agg
      )
      plot_shap_dependence(agg, v, model_name)
    }),
    vars
  )
  if (length(plots) == 1L) plots[[1L]] else plots
}


# =============================================================================
# compute_shap  - permutation SHAP algorithm
# =============================================================================

#' Permutation-based SHAP value computation
#'
#' For each feature `j` in `vars` and each observation `i`, runs `nsim` random
#' permutations of the `vars` feature ordering. In permutation `s`:
#'   - `vars` features appearing *before* `j` (the "coalition") keep actual
#'     values; `vars` features at `j` and after are swapped to a background
#'     row for `without_j`, while `with_j` keeps `j` actual but swaps
#'     features after `j`.
#'   - Non-`vars` columns always retain their actual observation values so the
#'     model can find every column it was trained on.
#'   - The marginal contribution is pred(with_j) - pred(without_j).
#' Averaging over permutations gives an unbiased Shapley value estimate.
#'
#' All `2 * n * nsim` rows for a single feature are stacked into one
#' data.frame and passed to [model_predict()] in a single call, following the
#' same batch-predict pattern as [compute_pdp()].
#'
#' @param X_full           data.frame of rows to explain  - ALL columns the
#'                         model needs, not just `vars`.
#' @param model            Fitted model object.
#' @param vars             `[character]` Names of the features whose SHAP
#'                         values are computed. Must be columns of `X_full`.
#' @param nsim             `[integer(1)]` Permutations per observation.
#' @param pre_process_fun  Pre-processing pipeline function.
#' @param feat_eng_fun     Feature-engineering pipeline function.
#' @param post_process_fun Post-processing pipeline function.
#'
#' @return data.frame with the same row count as `X_full` and one column per
#'   element of `vars` containing the SHAP values.
#'
#' @keywords internal
compute_shap <- function(
  X_full,
  model,
  vars,
  nsim,
  pre_process_fun,
  feat_eng_fun,
  post_process_fun
) {
  n       <- nrow(X_full)
  p       <- length(vars)
  n_block <- n * nsim

  shap_mat <- matrix(0.0, nrow = n, ncol = p, dimnames = list(NULL, vars))

  # Replicate the full data frame nsim times  - actual values for every column.
  # Non-vars columns will never be overwritten, so the model always sees them.
  X_rep <- X_full[rep(seq_len(n), times = nsim), , drop = FALSE]
  rownames(X_rep) <- NULL

  for (j in seq_len(p)) {
    # with_j and without_j start as exact copies of actual observation values.
    # We only overwrite the `vars` columns that appear after j in the
    # permutation; all other columns (including non-vars) stay actual.
    with_j    <- X_rep
    without_j <- X_rep
    rownames(with_j) <- rownames(without_j) <- NULL

    # Background pool: sample n_block rows from the full data.
    # We only copy their `vars` columns when swapping in background values.
    bg_idx  <- sample(n, n_block, replace = TRUE)
    bg_rows <- X_full[bg_idx, vars, drop = FALSE]
    rownames(bg_rows) <- NULL

    for (s in seq_len(nsim)) {
      idx_s <- ((s - 1L) * n + 1L):(s * n)

      # Random permutation of the p `vars` indices
      perm  <- sample(p)
      pos_j <- which(perm == j)

      # `vars` features that come AFTER j in this permutation
      post <- if (pos_j < p) perm[(pos_j + 1L):p] else integer(0L)

      # with_j:    replace `vars` features AFTER j with background values
      if (length(post) > 0L) {
        cols_post <- vars[post]
        with_j[idx_s, cols_post] <- bg_rows[idx_s, cols_post, drop = FALSE]
      }

      # without_j: replace j AND `vars` features AFTER j with background values
      cols_out <- vars[perm[pos_j:p]]
      without_j[idx_s, cols_out] <- bg_rows[idx_s, cols_out, drop = FALSE]
    }

    # -- Single predict call on the full stacked block (2 * n * nsim rows) ------
    # This mirrors compute_pdp()'s batch approach: one model_predict() call
    # per feature regardless of n or nsim.
    combined    <- rbind(with_j, without_j)
    combined_pp <- call_pipeline_fun(pre_process_fun,  "pre_process_fun",  combined)
    combined_fe <- as.data.frame(call_pipeline_fun(feat_eng_fun, "feat_eng_fun", combined_pp))
    all_preds   <- model_predict(model, combined_fe)
    all_preds   <- call_pipeline_fun(post_process_fun, "post_process_fun", all_preds, combined)

    preds_with    <- all_preds[seq_len(n_block)]
    preds_without <- all_preds[(n_block + 1L):(2L * n_block)]

    # Average marginal contributions over simulations.
    # diffs is ordered: sim 1 rows 1..n, sim 2 rows 1..n, ...
    diffs_mat     <- matrix(preds_with - preds_without, nrow = n, ncol = nsim)
    shap_mat[, j] <- rowMeans(diffs_mat)
  }

  as.data.frame(shap_mat)
}


# =============================================================================
# aggregate_shap_bin  - bin feature, aggregate mean SHAP + exposure
# =============================================================================

#' Bin a feature and aggregate mean SHAP value and exposure per bin
#'
#' Uses [compute_bins()] from pdp.R to apply the same binning logic as
#' [pdp()] and [one_way()], then computes exposure-weighted mean SHAP and
#' total exposure per bin.
#'
#' @param feat_vals `[numeric or character]` Raw feature values (length n).
#' @param shap_vals `[numeric]` SHAP values for this feature (length n).
#' @param expo_vals `[numeric]` Exposure weights (length n).
#' @param bins      `[integer(1)]` Number of bins for numeric features.
#' @param type_agg  `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#'
#' @return data.table with columns `.bin`, `mean_shap`, `exposure`.
#' @keywords internal
aggregate_shap_bin <- function(feat_vals, shap_vals, expo_vals, bins, type_agg) {
  bin_info <- compute_bins(feat_vals, bins, type_agg)

  dt <- data.table::data.table(
    .bin  = bin_info$labels,
    .shap = shap_vals,
    .expo_shap = expo_vals
  )

  agg <- dt[
    .bin != "NA",
    .(
      mean_shap = sum(.shap * .expo_shap, na.rm = TRUE) /
                    sum(.expo_shap, na.rm = TRUE),
      exposure  = sum(.expo_shap, na.rm = TRUE)
    ),
    by = .bin
  ]

  # Apply the same x-axis ordering as one_way() and pdp()
  x_levels <- smart_level_order(unique(agg$.bin))
  agg[, .bin := factor(.bin, levels = x_levels)]
  data.table::setorder(agg, .bin)
  agg[, .bin := as.character(.bin)]
  agg[]
}


# =============================================================================
# plot_shap_importance  - horizontal bar chart
# =============================================================================

#' Render SHAP feature importance chart
#'
#' Horizontal bar chart of **mean SHAP** (signed) per feature, sorted by
#' magnitude (mean |SHAP|) so the most influential feature is at the top.
#' Purple bars indicate a feature whose average effect **increases** the
#' prediction; blue bars indicate a feature that **decreases** it.
#' A zero reference line and colour legend subtitle make the direction
#' immediately readable.
#'
#' Styling matches [pdp()] and [one_way()]: transparent background, same
#' margins, `hovermode = "y unified"`.
#'
#' @param imp        data.frame with columns `feature`, `mean_shap`, and
#'                   `mean_abs_shap`.
#' @param model_name `[character(1)]` Label shown in the chart title.
#' @keywords internal
plot_shap_importance <- function(imp, model_name) {
  # Sort ascending by |SHAP| so plotly's bottom-to-top puts most important at top
  imp <- imp[order(imp$mean_abs_shap, decreasing = FALSE), ]
  imp$feature <- factor(imp$feature, levels = imp$feature)

  n_feat <- nrow(imp)

  # Purple = positive average effect (pushes prediction up)
  # Blue   = negative average effect (pushes prediction down)
  bar_colours <- ifelse(imp$mean_shap >= 0, "#9900cc", "#2171B5")
  sign_str    <- ifelse(imp$mean_shap > 0, "+", "")

  p <- plotly::plot_ly(as.data.frame(imp)) %>%
    plotly::add_trace(
      x           = ~mean_shap,
      y           = ~feature,
      type        = "bar",
      orientation = "h",
      marker      = list(color = bar_colours),
      hoverinfo   = "text",
      hovertext   = paste0(
        imp$feature, ": ", sign_str, sig_dig(imp$mean_shap, 5L)
      ),
      showlegend  = FALSE
    ) %>%
    plotly::layout(
      title = list(
        text = paste0(
          "<b>SHAP Feature Importance</b> &#8212; ", model_name,
          "<br><sup>",
          "<span style='color:#9900cc'>&#9632;</span> positive effect &nbsp;",
          "<span style='color:#2171B5'>&#9632;</span> negative effect",
          "</sup>"
        ),
        x    = 0.02,
        font = list(size = 15L)
      ),
      xaxis = list(
        title         = "Mean SHAP Value",
        showgrid      = TRUE,
        zeroline      = TRUE,
        zerolinecolor = "rgba(80,80,80,0.6)",
        zerolinewidth = 2L
      ),
      yaxis = list(
        title         = "",
        showgrid      = FALSE,
        automargin    = TRUE,
        categoryorder = "array",
        categoryarray = levels(imp$feature)
      ),
      legend        = list(x = 1.15, y = 0.5),
      margin        = list(t = 65L, b = 60L, l = 50L, r = 150L),
      hovermode     = "y unified",
      plot_bgcolor  = "rgba(0,0,0,0)",
      paper_bgcolor = "rgba(0,0,0,0)"
    )

  p$sizingPolicy$defaultHeight <- 400L + n_feat * 24L
  p
}


# =============================================================================
# plot_shap_dependence  - dual-axis: exposure bars + mean SHAP line
# =============================================================================

#' Render a SHAP dependence chart
#'
#' Dual-axis Plotly chart that exactly mirrors [plot_pdp()] and
#' `plot_one_way_simple()`:
#'   - Left axis  : yellow exposure bars
#'   - Right axis : mean SHAP per bin (purple line + markers), zero reference
#'                  line (dashed)
#'
#' The x-axis uses [smart_level_order()] so interval labels sort
#' chronologically / numerically, matching [one_way()] and [pdp()].
#'
#' @param agg        data.table from [aggregate_shap_bin()] with columns
#'                   `.bin`, `mean_shap`, `exposure`.
#' @param var        `[character(1)]` Feature name (x-axis label).
#' @param model_name `[character(1)]` Label used in the legend and title.
#' @keywords internal
plot_shap_dependence <- function(agg, var, model_name) {
  x_levels <- smart_level_order(unique(agg$.bin))
  df       <- as.data.frame(agg)

  col_shap <- "#9900cc"   # purple  - same as observed line in one_way/pdp
  col_zero <- "rgba(100,100,100,0.5)"

  global_zero <- 0

  p <- plotly::plot_ly(df)

  # -- Mean SHAP line (right axis) -----------------------------------------------
  p <- plotly::add_trace(
    p,
    x         = ~.bin,
    y         = ~mean_shap,
    yaxis     = "y2",
    type      = "scatter",
    mode      = "lines+markers",
    name      = paste0("mean_shap_", model_name),
    line      = list(color = col_shap),
    marker    = list(color = col_shap, symbol = "square"),
    hoverinfo = "text",
    hovertext = paste0(
      "SHAP (", var, "): ", sig_dig(df$mean_shap, 7L)
    )
  )

  # -- Zero reference line (right axis) ------------------------------------------
  p <- plotly::add_trace(
    p,
    x          = x_levels,
    y          = rep(global_zero, length(x_levels)),
    yaxis      = "y2",
    type       = "scatter",
    mode       = "lines",
    name       = "SHAP = 0",
    line       = list(color = col_zero, dash = "dash", width = 1.5),
    hoverinfo  = "none",
    showlegend = FALSE
  )

  # -- Exposure bars (left axis)  - identical to one_way() and pdp() -------------
  p <- plotly::add_trace(
    p,
    x         = ~.bin,
    y         = ~exposure,
    yaxis     = "y",
    type      = "bar",
    orientation = "v",
    name      = "Exposure",
    marker    = list(color = "#ffff00"),
    hoverinfo = "text",
    hovertext = paste0("Exposure: ", df$.bin, " = ", sig_dig(df$exposure, 7L))
  )

  # -- Layout  - identical structure to plot_pdp() --------------------------------
  p$sizingPolicy$defaultHeight <- 800
  p %>%
    plotly::layout(
      xaxis = list(
        title         = var,
        categoryorder = "array",
        categoryarray = x_levels
      ),
      yaxis = list(
        title    = "Exposure",
        showgrid = FALSE,
        autorange = TRUE
      ),
      yaxis2 = list(
        overlaying = "y",
        side       = "right",
        showgrid   = TRUE,
        autorange  = TRUE,
        title      = paste0("Mean SHAP (", var, ")")
      ),
      legend    = list(x = 1.15, y = 0.5),
      margin    = list(t = 25L, b = 100L, l = 50L, r = 50L),
      hovermode = "x",
      plot_bgcolor  = "rgba(0,0,0,0)",
      paper_bgcolor = "rgba(0,0,0,0)"
    )
}
