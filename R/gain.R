# =============================================================================
# gain.R
# Cumulative gains chart and Gini coefficient for modelblueprint objects.
# =============================================================================

# =============================================================================
# gain() — S3 generic
# =============================================================================

utils::globalVariables("perfect_model")

#' Cumulative Gains Chart
#'
#' Plots cumulative gains curves for one or more competing scores against a
#' perfect model baseline. The Gini coefficient for each score is shown in
#' the legend.
#'
#' @param data A `data.frame`, `data.table`, or `modelblueprint`.
#' @param ...  Arguments passed to methods.
#' @export
gain <- function(data, ...) UseMethod("gain")


#' Cumulative Gains Chart (default method)
#'
#' @param data     A `data.frame` or `data.table`.
#' @param pred     `[character]` Name(s) of competing score columns.
#' @param obs      `[character(1)]` Name of the target variable column.
#' @param exposure `[character(1)]` Name of the exposure column.
#'                 Default `"exposure"`.
#' @param title    `[character(1)]` Chart title.
#' @param ret      `"plot"`, `"data"`, or `"gini"`. Default `"plot"`.
#' @param ...      Unused.
#'
#' @return A plotly object, list of data.tables, or list of Gini values.
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   obs      = c(0, 1, 0, 1, 1),
#'   pred     = c(0.1, 0.9, 0.2, 0.8, 0.7),
#'   exposure = rep(1, 5)
#' )
#' gain(df, pred = "pred", obs = "obs", exposure = "exposure")
#' }
#' @method gain default
#' @export
gain.default <- function(
  data,
  pred = "predict",
  obs = NA_character_,
  exposure = "exposure",
  title = "Cumulative Gains",
  ret = c("plot", "data", "gini"),
  ...
) {
  ret <- match.arg(ret)

  # -- Validate ----------------------------------------------------------------
  if (length(obs) != 1L || is.na(obs)) {
    cli::cli_abort(
      "{.arg obs} must be a single column name (the observed target)."
    )
  }
  assert_col_exists(data, obs, "`obs`")
  assert_col_exists(data, pred, "`pred`")

  # Defensive copy — never mutate caller data
  # data.table::copy() ensures a deep copy so := never modifies the original
  dt <- data.table::copy(data.table::as.data.table(data))

  # Fall back to unit weights if exposure column doesn't exist
  if (!exposure %in% names(dt)) {
    dt[[exposure]] <- 1L
  }

  # Perfect model baseline — add before column selection so it's available
  dt[, perfect_model := .SD[[1L]], .SDcols = obs]

  # Keep only needed columns (including perfect_model)
  dt <- dt[, c(obs, pred, exposure, "perfect_model"), with = FALSE]
  perfect <- compute_cumulative(dt, "perfect_model", obs, exposure)
  list_sets <- list(perfect$data)
  list_gini <- list(perfect$gini)

  # One entry per competing score
  for (score in pred) {
    result <- compute_cumulative(dt, score, obs, exposure)
    list_sets <- c(list_sets, list(result$data))
    list_gini <- c(list_gini, list(result$gini))
  }

  switch(
    ret,
    plot = plot_gain(list_sets, pred, title, list_gini),
    data = list_sets,
    gini = list_gini
  )
}


#' @rdname gain
#' @method gain modelblueprint
#'
#' @param data  A `modelblueprint` object.
#' @param set   Which dataset to use: `"train"`, `"test"`, or `"holdout"`.
#' @param title Chart title. Defaults to `model_display_name`.
#' @param ret   `"plot"`, `"data"`, or `"gini"`. Default `"plot"`.
#' @param ...   Passed to the default method.
#' @param precomputed_preds `[numeric | NULL]` Optional vector of pre-computed
#'   predictions (one per row of the requested `set`). When supplied, the
#'   internal `predict.modelblueprint()` call is skipped. Use this in loops or
#'   dashboards where predictions have already been computed to avoid redundant
#'   scoring.
#'
#' @return A plotly object, list of data.tables, or list of Gini values.
#'
#' @examples
#' \dontrun{
#' mb <- modelblueprint(
#'   model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
#'   train  = mtcars,
#'   y_name = "vs",
#'   model_display_name = "logistic_vs"
#' )
#' gain(mb)
#' }
#' @export
gain.modelblueprint <- function(
  data,
  set = c("train", "test", "holdout"),
  title = NULL,
  ret = c("plot", "data", "gini"),
  ...,
  precomputed_preds = NULL
) {
  set <- match.arg(set)
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

  # Resolve exposure — fall back to unit weights
  exposure <- resolve_exposure(data, df)
  df <- as.data.frame(df)
  if (exposure == "vec_of_ones") {
    df[[".exposure_ones"]] <- 1L
    exposure <- ".exposure_ones"
  }

  # Attach in-sample predictions — copy already made above via as.data.frame
  pred_col <- if (!is.na(data@model_display_name)) {
    data@model_display_name
  } else {
    "model_pred"
  }
  if (!is.null(precomputed_preds)) {
    df[[pred_col]] <- precomputed_preds
  } else {
    df[[pred_col]] <- predict.modelblueprint(data, df)
  }

  chart_title <- title %||% pred_col

  gain.default(
    df,
    pred = pred_col,
    obs = data@y_name,
    exposure = exposure,
    title = chart_title,
    ret = ret,
    ...
  )
}

# The package-qualified S7 class method ("modelblueprint::modelblueprint") is
# registered in .onLoad() via registerS3method(); see modelblueprint.R.


# =============================================================================
# Internal: compute_cumulative
# =============================================================================

#' @keywords internal
#' @noRd
compute_cumulative <- function(dt, variable, obs, exposure) {
  set <- data.table::copy(dt)

  # Sort descending by score per unit exposure
  ord <- order(-(set[[variable]] / set[[exposure]]))
  set <- set[ord]

  cum_obs <- paste0("cum_", obs)
  cum_variable <- paste0("cum_", variable)
  cum_exposure <- paste0("cum_", exposure)

  set[, (cum_obs) := cumsum(.SD[[1L]]), .SDcols = obs]
  set[, (cum_variable) := cumsum(.SD[[1L]]), .SDcols = variable]
  set[, (cum_exposure) := cumsum(.SD[[1L]]), .SDcols = exposure]

  # Compute totals outside data.table j-expressions to avoid scope issues
  total_obs <- sum(dt[[obs]], na.rm = TRUE)
  total_variable <- sum(dt[[variable]], na.rm = TRUE)
  total_exposure <- sum(dt[[exposure]], na.rm = TRUE)

  # Normalise to [0, 1]
  set[, (cum_obs) := .SD[[1L]] / total_obs, .SDcols = cum_obs]
  set[, (cum_variable) := .SD[[1L]] / total_variable, .SDcols = cum_variable]
  set[, (cum_exposure) := .SD[[1L]] / total_exposure, .SDcols = cum_exposure]

  # Gini via trapezoidal integration
  auc <- trapz(as.numeric(set[[cum_exposure]]), as.numeric(set[[cum_obs]]))
  gini <- (auc - 0.5) * 2

  # Align cum_variable to the obs curve for plotting
  set[, (cum_variable) := .SD[[1L]], .SDcols = cum_obs]

  keep <- c(cum_exposure, cum_variable)
  list(data = set[, .SD, .SDcols = keep], gini = gini, auc = auc)
}


# =============================================================================
# Internal: plot_gain
# =============================================================================

#' @keywords internal
#' @noRd
plot_gain <- function(list_sets, scores, title, list_gini) {
  n <- length(scores)
  colors <- c(
    "rgb(237,41,57)",
    RColorBrewer::brewer.pal(max(3L, n), "Paired")
  )[seq_len(n)]

  p <- plotly::plot_ly()
  p <- plotly::layout(
    p,
    title = title,
    xaxis = list(title = "Cumulative % of Exposure", rangemode = "tozero"),
    yaxis = list(
      title = "Cumulative % of Target",
      rangemode = "tozero",
      showgrid = FALSE
    ),
    legend = list(x = 1.05, y = 0.5),
    margin = list(t = 25, b = 100, l = 50, r = 50)
  )

  ref <- list_sets[[1L]]
  x_col <- names(ref)[1L]

  # Diagonal reference line — mean model (y = x)
  p <- plotly::add_lines(
    p,
    x = ref[[x_col]],
    y = ref[[x_col]],
    name = "Mean model, Gini: 0.000",
    line = list(color = "rgb(180,180,180)", dash = "dot", width = 1L)
  )

  # Perfect model curve — upper bound of what any model can achieve
  gini_perfect <- as.numeric(list_gini[[1L]])
  p <- plotly::add_lines(
    p,
    x = ref[[x_col]],
    y = ref[[names(ref)[2L]]],
    name = sprintf("Perfect model, Gini: %.3f", gini_perfect),
    line = list(color = "rgb(0,0,0)", dash = "dash", width = 1L)
  )

  # One line per competing score
  for (i in seq_along(scores)) {
    s <- list_sets[[i + 1L]]
    x_col <- names(s)[1L]
    y_col <- names(s)[2L]
    gini_i <- as.numeric(list_gini[[i + 1L]])
    p <- plotly::add_lines(
      p,
      x = s[[x_col]],
      y = s[[y_col]],
      name = sprintf("%s, Gini: %.3f", scores[i], gini_i),
      line = list(color = colors[i])
    )
  }

  p
}


# =============================================================================
# Internal: trapz
# =============================================================================

#' @keywords internal
#' @noRd
trapz <- function(x, y) {
  if (missing(y)) {
    if (length(x) == 0L) {
      return(0)
    }
    y <- x
    x <- seq_along(x)
  }
  if (length(x) == 0L && length(y) == 0L) {
    return(0)
  }
  if (
    !(is.numeric(x) || is.complex(x)) ||
      !(is.numeric(y) || is.complex(y))
  ) {
    cli::cli_abort("{.arg x} and {.arg y} must be numeric or complex vectors.")
  }
  m <- length(x)
  if (length(y) != m) {
    cli::cli_abort("{.arg x} and {.arg y} must be the same length.")
  }
  if (m <= 1L) {
    return(0)
  }
  sum(diff(x) * (y[-m] + y[-1L])) / 2
}
