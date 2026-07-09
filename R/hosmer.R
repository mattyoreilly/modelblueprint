# =============================================================================
# pred_vs_obs.R
# Hosmer-style predicted vs observed calibration plot.
# =============================================================================


# =============================================================================
# pred_vs_obs() — S3 generic
# =============================================================================

#' Predicted vs Observed Calibration Plot
#'
#' Creates a Hosmer-style calibration chart showing average predicted values
#' against average observed values across bins of the prediction space. A
#' yellow exposure bar on the secondary axis shows the distribution of data.
#'
#' @param data A `data.frame`, `data.table`, or `modelblueprint`.
#' @param ...  Arguments passed to methods.
#' @export
pred_vs_obs <- function(data, ...) UseMethod("pred_vs_obs")


#' @rdname pred_vs_obs
#' @method pred_vs_obs default
#'
#' @param data     A `data.frame` or `data.table`.
#' @param pred     `[character(1)]` Name of the predictions column.
#' @param obs      `[character(1)]` Name of the observed target column.
#' @param exposure `[character(1)]` Name of the exposure column. If the column
#'                 is absent, every row is given weight 1.
#'                 Default `"exposure"`.
#' @param bins     `[integer(1)]` Number of bins. Default `10L`.
#' @param type_agg `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#'                 Default `"equal_exposure"`.
#' @param title    `[character(1)]` Chart title. Default `""`.
#' @param ret      `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.
#' @param ...      Unused.
#'
#' @return A plotly object or data.table depending on `ret`.
#' @export
pred_vs_obs.default <- function(
  data,
  pred = "predict",
  obs = "observed",
  exposure = "exposure",
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  title = "",
  ret = c("plot", "data"),
  ...
) {
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  assert_col_exists(data, obs, "`obs`")
  assert_col_exists(data, pred, "`pred`")

  # Select only the columns we need *before* coercing, so a wide frame isn't
  # duplicated to use obs/pred/exposure. A missing exposure column falls back
  # to unit weights, matching one_way() and gain(). The list() step builds an
  # independent working table, so the caller's data is never mutated.
  has_expo <- exposure %in% names(data)
  keep <- c(obs, pred, if (has_expo) exposure)
  narrow <- if (data.table::is.data.table(data)) {
    data[, keep, with = FALSE]
  } else {
    data[keep]
  }
  dt <- data.table::as.data.table(narrow)
  dt <- dt[,
    list(
      .obs = .SD[[1L]],
      .pred = .SD[[2L]],
      .expo = if (has_expo) .SD[[3L]] else 1
    ),
    .SDcols = keep
  ]

  # Predictions per unit exposure — this is the x-axis variable
  # Extract as plain vector before passing to bin_pred (avoids data.table scope issues)
  rate <- dt$.pred / dt$.expo
  binned <- bin_pred(rate, bins, type_agg)
  dt[, .bin := binned$idx]
  bin_labels <- make_interval_labels(binned$breaks)

  # Aggregate by integer bin — order is numerically correct.
  # Take plain grouped sums (GForce-eligible) then divide; a per-group division
  # inside j would disable GForce.
  agg <- dt[,
    list(
      obs_sum  = sum(.obs),
      pred_sum = sum(.pred),
      exposure = sum(.expo)
    ),
    by = .bin
  ]
  agg[, obs_mean := obs_sum / exposure]
  agg[, pred_mean := pred_sum / exposure]
  agg[, c("obs_sum", "pred_sum") := NULL]
  data.table::setcolorder(agg, c(".bin", "obs_mean", "pred_mean", "exposure"))

  # Sort by bin integer then convert to readable labels
  agg <- agg[order(.bin)]
  agg[, .bin := factor(bin_labels[.bin], levels = bin_labels)]

  switch(ret, plot = plot_pred_vs_obs(agg, obs, title), data = agg)
}


#' @rdname pred_vs_obs
#' @method pred_vs_obs modelblueprint
#'
#' @param data     A `modelblueprint` object.
#' @param set      `[character]` Dataset splits to use: any of `"train"`,
#'                 `"test"`, `"holdout"`. Defaults to all available (non-NULL)
#'                 sets. When more than one set is used, a named list with
#'                 one result per set is returned.
#' @param bins     `[integer(1)]` Number of bins. Default `10L`.
#' @param type_agg `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @param title    `[character(1)]` Chart title. Defaults to
#'                 `model_display_name` (with the set name appended when
#'                 plotting multiple sets).
#' @param ret      `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.
#' @param ...      Passed to [pred_vs_obs.default()].
#' @param precomputed_preds `[numeric | NULL]` Optional vector of pre-computed
#'   predictions (one per row of the requested `set`). When supplied, the
#'   internal `predict.modelblueprint()` call is skipped.
#'
#' @return A plotly object or data.table depending on `ret`.
#'
#' @examples
#' \donttest{
#' mb <- modelblueprint(
#'   model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
#'   train  = mtcars,
#'   y_name = "vs",
#'   model_display_name = "logistic_vs"
#' )
#' pred_vs_obs(mb)
#' }
#' @export
pred_vs_obs.modelblueprint <- function(
  data,
  set = c("train", "test", "holdout"),
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  title = NULL,
  ret = c("plot", "data"),
  ...,
  precomputed_preds = NULL
) {
  set <- resolve_sets(data, set)
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  # Multiple sets: one result per set, returned as a named list
  if (length(set) > 1L) {
    if (!is.null(precomputed_preds)) {
      cli::cli_abort("{.arg precomputed_preds} requires a single {.arg set}.")
    }
    base_title <- title %||% (data@model_display_name %|NA|% "Predicted vs Observed")
    return(lapply(stats::setNames(set, set), function(s) {
      pred_vs_obs(
        data, set = s, bins = bins, type_agg = type_agg,
        title = paste(base_title, s, sep = " - "), ret = ret, ...
      )
    }))
  }

  df <- prop(data, set)
  if (is.null(df)) {
    cli::cli_abort(
      "modelblueprint {.arg @{set}} is NULL. Supply data when constructing."
    )
  }

  if (is.na(data@y_name)) {
    cli::cli_abort(
      "{.arg @y_name} is not set. Specify the target variable name."
    )
  }

  # Resolve exposure — unit-weight fallback, zeros replaced with @expo_0_rep
  resolved <- resolve_exposure_values(data, df)
  df <- resolved$df
  exposure <- resolved$exposure

  # Apply pipeline to get engineered data for predictions and obs alignment.
  # Same logic as pdp.default: if feat_eng_fun transforms the response, obs and
  # predictions must be on the same scale.
  df_pp  <- call_pipeline_fun(data@pre_process_fun, "pre_process_fun", df)
  df_eng <- as.data.frame(call_pipeline_fun(data@feat_eng_fun, "feat_eng_fun", df_pp))
  if (data@y_name %in% names(df_eng)) {
    df[[data@y_name]] <- df_eng[[data@y_name]]
  }

  # Attach predictions via the full pipeline. .pred_col_name() keeps the column
  # name consistent across all modelblueprint diagnostics.
  pred_col <- .pred_col_name(data)
  if (!is.null(precomputed_preds)) {
    df[[pred_col]] <- precomputed_preds
  } else {
    # Reuse the engineered frame to score instead of predict.modelblueprint(),
    # which would re-run pre_process_fun + feat_eng_fun a second time.
    raw_preds <- model_predict(data@model, df_eng)
    df[[pred_col]] <- call_pipeline_fun(
      data@post_process_fun,
      "post_process_fun",
      raw_preds,
      df
    )
  }

  chart_title <- title %||% (data@model_display_name %|NA|% "Predicted vs Observed")

  pred_vs_obs.default(
    df,
    pred = pred_col,
    obs = data@y_name,
    exposure = exposure,
    bins = bins,
    type_agg = type_agg,
    title = chart_title,
    ret = ret,
    ...
  )
}

# The package-qualified S7 class method ("modelblueprint::modelblueprint") is
# registered in .onLoad() via registerS3method(); see modelblueprint.R.


# =============================================================================
# Internal: bin_pred
# =============================================================================

#' Bin the prediction x-axis into equal-exposure or equal-range buckets
#' @keywords internal
#' @noRd
bin_pred <- function(x, bins, type_agg) {
  if (type_agg == "equal_exposure") {
    probs <- seq(0, 1, length.out = bins + 1L)
    breaks <- unique(quantile(x, probs = probs, na.rm = TRUE))
  } else {
    breaks <- unique(seq(
      min(x, na.rm = TRUE),
      max(x, na.rm = TRUE),
      length.out = bins + 1L
    ))
  }

  if (length(breaks) < 2L) {
    eps <- max(abs(breaks[1L]) * 1e-6, 1e-10)
    breaks <- c(breaks[1L] - eps, breaks[1L] + eps)
  }

  # Integer indices: 1 = lowest bin. Callers sort on this integer,
  # then apply labels — avoiding all lexical ordering problems.
  list(
    idx = as.integer(cut(
      x,
      breaks = breaks,
      labels = FALSE,
      include.lowest = TRUE
    )),
    breaks = breaks
  )
}

#' Format break points as readable interval labels
#' @keywords internal
#' @noRd
make_interval_labels <- function(breaks) {
  n <- length(breaks) - 1L
  left <- breaks[seq_len(n)]
  right <- breaks[seq_len(n) + 1L]
  gap <- min(diff(breaks))
  # Enough sig figs to distinguish adjacent breaks — no upper cap.
  # ceiling(-log10(gap)) + 2 gives 2 extra digits beyond the gap's leading digit.
  sig <- max(3L, ceiling(-log10(gap)) + 2L)
  sprintf("(%s, %s]", signif(left, sig), signif(right, sig))
}


# =============================================================================
# Internal: plot_pred_vs_obs
# =============================================================================

#' Build the predicted vs observed plotly object
#' @keywords internal
#' @noRd
plot_pred_vs_obs <- function(agg, obs, title) {
  # Use integer positions so the line trace is guaranteed to connect
  # bins left-to-right. Categorical x-axes in plotly map string labels
  # to positions using internal alphabetical ordering for line/scatter
  # traces, regardless of categoryarray — causing the line to double back
  # when a label like "(3.22e-16, 0.1]" sorts after "(0.x, ...)".
  x_pos <- seq_len(nrow(agg))
  x_text <- as.character(agg$.bin)

  p <- plotly::plot_ly()

  # Exposure bars — secondary y-axis
  p <- plotly::add_bars(
    p,
    x = x_pos,
    y = agg$exposure,
    name = "Exposure",
    marker = list(color = "#ffff00"),
    yaxis = "y2"
  )

  # Observed points — primary y-axis
  p <- plotly::add_markers(
    p,
    x = x_pos,
    y = agg$obs_mean,
    name = "Observed",
    marker = list(size = 7, color = "rgb(0,0,128)", symbol = "circle"),
    yaxis = "y"
  )

  # Predicted line — primary y-axis
  p <- plotly::add_lines(
    p,
    x = x_pos,
    y = agg$pred_mean,
    name = "Predicted",
    line = list(color = "rgb(0,0,0)", width = 2, dash = "dash"),
    yaxis = "y"
  )

  plotly::layout(
    p,
    title = title,
    xaxis = list(
      title = "Predicted (binned)",
      tickangle = -45,
      tickmode = "array",
      tickvals = x_pos,
      ticktext = x_text
    ),
    yaxis = list(
      title = "Observed / Predicted rate",
      overlaying = "y2",
      showgrid = FALSE
    ),
    yaxis2 = list(
      title = "Exposure",
      side = "right",
      showgrid = FALSE
    ),
    legend = list(x = 1.1, y = 0.5),
    margin = list(t = 25, b = 120, l = 50, r = 80),
    barmode = "overlay"
  )
}
