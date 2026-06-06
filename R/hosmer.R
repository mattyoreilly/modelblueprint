# =============================================================================
# pred_vs_obs.R
# Hosmer-style predicted vs observed calibration plot.
#
# Design:
#   - pred_vs_obs() is an S3 generic — works on data.frames directly or via
#     pred_vs_obs.modelblueprint() which pulls slots automatically
#   - Binning reuses the same equal-exposure / equal-range logic as one_way()
#   - No external dependencies beyond data.table and plotly
#   - No mutation of caller data
# =============================================================================

utils::globalVariables(c("left", "right", ".expo", ".pred", ".obs", ".bin"))


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
#' @param exposure `[character(1)]` Name of the exposure column.
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

  # Defensive copy — never mutate caller data
  dt <- data.table::as.data.table(data)
  dt <- dt[,
    list(.obs = .SD[[1L]], .pred = .SD[[2L]], .expo = .SD[[3L]]),
    .SDcols = c(obs, pred, exposure)
  ]

  # Predictions per unit exposure — this is the x-axis variable
  # Extract as plain vector before passing to bin_pred (avoids data.table scope issues)
  rate <- dt$.pred / dt$.expo
  binned <- bin_pred(rate, bins, type_agg)
  dt[, .bin := binned$idx]
  bin_labels <- make_interval_labels(binned$breaks)

  # Aggregate by integer bin — order is numerically correct
  agg <- dt[,
    list(
      obs_mean = sum(.obs) / sum(.expo),
      pred_mean = sum(.pred) / sum(.expo),
      exposure = sum(.expo)
    ),
    by = .bin
  ]

  # Sort by bin integer then convert to readable labels
  agg <- agg[order(.bin)]
  agg[, .bin := factor(bin_labels[.bin], levels = bin_labels)]

  switch(ret, plot = plot_pred_vs_obs(agg, obs, title), data = agg)
}


#' @rdname pred_vs_obs
#' @method pred_vs_obs modelblueprint
#'
#' @param data     A `modelblueprint` object.
#' @param set      `[character(1)]` Which dataset to use: `"train"`,
#'                 `"test"`, or `"holdout"`. Default `"train"`.
#' @param bins     `[integer(1)]` Number of bins. Default `10L`.
#' @param type_agg `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @param title    `[character(1)]` Chart title. Defaults to
#'                 `model_display_name`.
#' @param ret      `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.
#' @param ...      Passed to [pred_vs_obs.default()].
#'
#' @return A plotly object or data.table depending on `ret`.
#'
#' @examples
#' \dontrun{
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
  ...
) {
  set <- match.arg(set)
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  df <- prop(data, set)
  if (is.null(df)) {
    stop(
      sprintf(
        "modelblueprint `@%s` is NULL. Supply data when constructing the object.",
        set
      ),
      call. = FALSE
    )
  }

  if (is.na(data@y_name)) {
    stop(
      "modelblueprint `@y_name` is not set.",
      call. = FALSE
    )
  }

  # Resolve exposure
  exposure <- resolve_exposure(data, df)
  df <- as.data.frame(df)
  if (exposure == "vec_of_ones") {
    df[[".exposure_ones"]] <- 1L
    exposure <- ".exposure_ones"
  }

  # Apply pipeline to get engineered data for predictions and obs alignment.
  # Same logic as pdp.default: if feat_eng_fun transforms the response, obs and
  # predictions must be on the same scale.
  df_eng <- as.data.frame(data@feat_eng_fun(data@pre_process_fun(df)))
  if (data@y_name %in% names(df_eng)) {
    df[[data@y_name]] <- df_eng[[data@y_name]]
  }

  # Attach predictions via the full pipeline
  pred_col <- if (!is.na(data@model_display_name)) {
    data@model_display_name
  } else {
    "pred"
  }
  df[[pred_col]] <- predict.modelblueprint(data, df)

  chart_title <- title %||%
    (data@model_display_name %||% "Predicted vs Observed")

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

# Register package-qualified S7 class name for UseMethod dispatch
`pred_vs_obs.modelblueprint::modelblueprint` <- pred_vs_obs.modelblueprint


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
