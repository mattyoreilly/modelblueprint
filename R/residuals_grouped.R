# =============================================================================
# residuals_grouped.R
# Grouped residuals vs predicted plot with loess trend line.
# =============================================================================

utils::globalVariables(c(
  "midpoint",
  "res",
  "loe_pred",
  "loe_low",
  "loe_upp",
  ".obs",
  ".pred",
  ".expo",
  "rate",
  "bin",
  "obs_mean",
  "obs_sum",
  "pred_mean",
  "pred_sum"
))


# =============================================================================
# residuals_grouped() -- S3 generic
# =============================================================================

#' Grouped Residuals vs Predicted Plot
#'
#' Bins predictions by exposure, computes grouped residuals, and overlays a
#' loess trend line with a 95% confidence interval. Useful for diagnosing
#' systematic model bias across the prediction range.
#'
#' @param data A `data.frame`, `data.table`, or `modelblueprint`.
#' @param ...  Arguments passed to methods.
#' @export
residuals_grouped <- function(data, ...) UseMethod("residuals_grouped")


#' @rdname residuals_grouped
#' @method residuals_grouped default
#'
#' @param data            A `data.frame` or `data.table`.
#' @param pred            `[character(1)]` Name of the predictions column.
#' @param obs             `[character(1)]` Name of the observed target column.
#' @param exposure        `[character(1)]` Name of the exposure column.
#'                        Default `"exposure"`.
#' @param exposure_per_bin `[numeric(1)]` Target exposure per bin. Controls
#'                        granularity -- smaller values give more bins.
#'                        Default `10`.
#' @param residual_type   `[character(1)]` `"raw"` (`obs - pred`) or
#'                        `"pearson"` (`(obs - pred) / sqrt(pred)`).
#'                        Default `"raw"`.
#' @param title           `[character(1)]` Chart title. Default `""`.
#' @param ret             `[character(1)]` `"plot"` or `"data"`.
#'                        Default `"plot"`.
#' @param ...             Unused.
#'
#' @return A plotly object or data.table depending on `ret`.
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   obs      = rbinom(500, 1, 0.3),
#'   pred     = runif(500, 0.1, 0.5),
#'   exposure = rep(1, 500)
#' )
#' residuals_grouped(df, pred = "pred", obs = "obs", exposure = "exposure")
#' }
#' @export
residuals_grouped.default <- function(
  data,
  pred = "predict",
  obs = "observed",
  exposure = "exposure",
  exposure_per_bin = 10,
  residual_type = c("raw", "pearson"),
  title = "",
  ret = c("plot", "data"),
  ...
) {
  residual_type <- match.arg(residual_type)
  ret <- match.arg(ret)

  # Defensive copy -- never mutate caller data
  dt <- data.table::as.data.table(data)
  dt <- dt[,
    list(.obs = .SD[[1L]], .pred = .SD[[2L]], .expo = .SD[[3L]]),
    .SDcols = c(obs, pred, exposure)
  ]

  # Determine number of bins from target exposure per bin
  avg_expo <- sum(dt$.expo) / nrow(dt)
  n_bins <- max(3L, round(nrow(dt) / (exposure_per_bin / avg_expo)))

  # Bin by predictions per unit exposure (rate), compute bin midpoint
  dt[, rate := .pred / .expo]
  breaks <- unique(quantile(
    dt$rate,
    probs = seq(0, 1, length.out = n_bins + 1L),
    na.rm = TRUE
  ))

  # Guard: if all rates are identical unique() collapses breaks to one value
  # -- add a tiny epsilon spread so cut() receives at least 2 break points
  if (length(breaks) < 2L) {
    eps <- max(abs(breaks[1L]) * 1e-6, 1e-10)
    breaks <- c(breaks[1L] - eps, breaks[1L] + eps)
  }

  dt[, bin := cut(rate, breaks = breaks, include.lowest = TRUE)]

  # Midpoint of each bin for x-axis
  bin_levels <- levels(dt$bin)
  midpoints <- vapply(
    bin_levels,
    function(lbl) {
      nums <- as.numeric(regmatches(lbl, gregexpr("-?[0-9.]+", lbl))[[1L]])
      mean(nums[c(1L, length(nums))])
    },
    numeric(1L)
  )
  dt[, midpoint := midpoints[as.integer(bin)]]

  # Aggregate per midpoint
  agg <- dt[,
    list(
      obs_sum = sum(.obs),
      pred_sum = sum(.pred),
      exposure = sum(.expo)
    ),
    by = midpoint
  ]

  agg[, obs_mean := obs_sum / exposure]
  agg[, pred_mean := pred_sum / exposure]

  # Compute residuals
  agg[,
    res := switch(
      residual_type,
      raw = obs_mean - pred_mean,
      pearson = (obs_mean - pred_mean) / sqrt(pmax(pred_mean, 1e-10))
    )
  ]

  agg <- agg[order(midpoint)]

  if (ret == "data") {
    return(agg)
  }

  if (nrow(agg) < 3L) {
    cli::cli_warn(c(
      "{.fn residuals_grouped}: fewer than 3 bins -- cannot fit loess.",
      i = "Increase data size or reduce {.arg exposure_per_bin}."
    ))
    return(agg)
  }

  plot_residuals_grouped(agg, title, exposure_per_bin)
}


#' @rdname residuals_grouped
#' @method residuals_grouped modelblueprint
#'
#' @param data             A `modelblueprint` object.
#' @param set              `[character(1)]` Dataset to use: `"train"`,
#'                         `"test"`, or `"holdout"`. Default `"train"`.
#' @param exposure_per_bin `[numeric(1)]` Target exposure per bin.
#'                         Default `2500`. Automatically reduced if the
#'                         dataset is too small for meaningful grouping.
#' @param residual_type    `[character(1)]` `"raw"` or `"pearson"`.
#' @param title            `[character(1)]` Chart title. Defaults to
#'                         `model_display_name`.
#' @param ret              `[character(1)]` `"plot"` or `"data"`.
#' @param ...              Passed to [residuals_grouped.default()].
#' @param precomputed_preds `[numeric | NULL]` Optional vector of pre-computed
#'   predictions (one per row of the requested `set`). When supplied, the
#'   internal `predict.modelblueprint()` call is skipped.
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
#' residuals_grouped(mb)
#' }
#' @export
residuals_grouped.modelblueprint <- function(
  data,
  set = c("train", "test", "holdout"),
  exposure_per_bin = 2500,
  residual_type = c("raw", "pearson"),
  title = NULL,
  ret = c("plot", "data"),
  ...,
  precomputed_preds = NULL
) {
  set <- match.arg(set)
  residual_type <- match.arg(residual_type)
  ret <- match.arg(ret)

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

  # Resolve exposure -- fall back to unit weights
  exposure <- resolve_exposure(data, df)
  df <- as.data.frame(df)
  if (exposure == "vec_of_ones") {
    df[[".exposure_ones"]] <- 1L
    exposure <- ".exposure_ones"
  }

  # Align obs scale with predictions — if feat_eng_fun transforms the response,
  # update obs in df so it matches the prediction scale.
  df_pp  <- call_pipeline_fun(data@pre_process_fun, "pre_process_fun", df)
  df_eng <- as.data.frame(call_pipeline_fun(data@feat_eng_fun, "feat_eng_fun", df_pp))
  if (data@y_name %in% names(df_eng)) {
    df[[data@y_name]] <- df_eng[[data@y_name]]
  }

  # Attach predictions
  pred_col <- if (!is.na(data@model_display_name)) {
    data@model_display_name
  } else {
    "pred"
  }
  if (!is.null(precomputed_preds)) {
    df[[pred_col]] <- precomputed_preds
  } else {
    df[[pred_col]] <- predict.modelblueprint(data, df)
  }

  # Guard: ensure at least 3 bins are possible
  total_expo <- sum(df[[exposure]], na.rm = TRUE)
  exposure_per_bin <- min(exposure_per_bin, total_expo / 3)

  chart_title <- title %||% (data@model_display_name %||% "Grouped Residuals")

  residuals_grouped.default(
    df,
    pred = pred_col,
    obs = data@y_name,
    exposure = exposure,
    exposure_per_bin = exposure_per_bin,
    residual_type = residual_type,
    title = chart_title,
    ret = ret,
    ...
  )
}

# The package-qualified S7 class method ("modelblueprint::modelblueprint") is
# registered in .onLoad() via registerS3method(); see modelblueprint.R.


# =============================================================================
# Internal: plot_residuals_grouped
# =============================================================================

#' @keywords internal
#' @noRd
plot_residuals_grouped <- function(agg, title, exposure_per_bin) {
  # Fit loess with 95% CI -- suppress near-singularity warnings that fire
  # on small datasets; the plot is still useful even with imprecise CIs
  lo <- suppressWarnings(stats::loess(agg$res ~ agg$midpoint))
  pred <- suppressWarnings(stats::predict(lo, se = TRUE))
  t_crit <- stats::qt(0.975, df = max(pred$df, 1L))

  agg[, loe_pred := pred$fit]
  agg[, loe_low := pred$fit - t_crit * pred$se.fit]
  agg[, loe_upp := pred$fit + t_crit * pred$se.fit]

  p <- plotly::plot_ly()

  # 95% loess confidence ribbon
  p <- plotly::add_ribbons(
    p,
    x = agg$midpoint,
    ymin = agg$loe_low,
    ymax = agg$loe_upp,
    name = "95% loess CI",
    line = list(width = 0),
    fillcolor = "rgba(54,96,146,0.2)"
  )

  # Loess trend line
  p <- plotly::add_lines(
    p,
    x = agg$midpoint,
    y = agg$loe_pred,
    name = "Loess",
    line = list(color = "rgb(0,94,128)", width = 2)
  )

  # Residual points
  p <- plotly::add_markers(
    p,
    x = agg$midpoint,
    y = agg$res,
    name = "Residual",
    marker = list(size = 6, color = "rgb(0,0,128)", symbol = "circle")
  )

  # Zero reference line
  p <- plotly::add_lines(
    p,
    x = range(agg$midpoint),
    y = c(0, 0),
    name = "Zero",
    line = list(color = "rgb(180,180,180)", width = 1, dash = "dot"),
    showlegend = FALSE
  )

  plotly::layout(
    p,
    title = title,
    xaxis = list(title = "Predicted rate", rangemode = "tozero"),
    yaxis = list(title = "Residual", showgrid = FALSE, zeroline = TRUE),
    legend = list(x = 1.05, y = 0.5),
    margin = list(t = 25, b = 80, l = 50, r = 80),
    annotations = list(list(
      x = 1,
      y = -0.12,
      text = sprintf("Mean exposure per bin: %.0f", exposure_per_bin),
      showarrow = FALSE,
      xref = "paper",
      yref = "paper",
      xanchor = "right",
      yanchor = "auto",
      font = list(size = 9, color = "rgb(128,128,128)")
    ))
  )
}
