# =============================================================================
# sami.R
# SAMI (double lift chart) — plots ratio of competing predictions against
# observed loss to diagnose where two models disagree.
# =============================================================================


# =============================================================================
# sami() — S3 generic
# =============================================================================

#' SAMI Double Lift Chart
#'
#' SAMI stands for **Score Analysis for Model Improvement** — an actuarial
#' diagnostic technique for comparing two competing models.
#'
#' For each pair of competing predictions, bins the ratio of one prediction to
#' another and plots the observed mean alongside both model means per bin.
#' Useful for diagnosing where two models systematically disagree and which
#' model better tracks the observed response across segments of the data.
#'
#' @param data A `data.frame`, `data.table`, or a list of `modelblueprint`
#'             objects.
#' @param ...  Arguments passed to methods.
#' @export
sami <- function(data, ...) UseMethod("sami")


#' @rdname sami
#' @method sami default
#'
#' @param data      A `data.frame` or `data.table`.
#' @param obs       `[character(1)]` Name of the observed target column.
#' @param pred      `[character]` Names of two or more competing prediction
#'                  columns.
#' @param bins      `[integer(1)]` Number of bins. Default `50L`.
#' @param exposure  `[character(1)]` Name of the exposure column.
#'                  Default `"exposure"`.
#' @param type_agg  `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#'                  Default `"equal_exposure"`.
#' @param recalib   `[logical(1)]` If `TRUE`, recalibrate each prediction to
#'                  have the same mean as `obs` before computing ratios.
#'                  Default `FALSE`.
#' @param ret       `[character(1)]` `"plot"` returns a named list of plotly
#'                  objects (one per pair). `"data"` returns the augmented
#'                  data.table with ratio columns added. Default `"plot"`.
#' @param ...       Unused.
#'
#' @return A named list of plotly objects or a data.table depending on `ret`.
#'
#' @examples
#' \donttest{
#' df <- data.frame(
#'   obs      = rnorm(500, 100),
#'   pred1    = rnorm(500, 100),
#'   pred2    = rnorm(500, 105),
#'   exposure = rep(1, 500)
#' )
#' sami(df, obs = "obs", pred = c("pred1", "pred2"), bins = 10)
#' }
#' @export
sami.default <- function(
  data,
  obs,
  pred,
  bins = 50L,
  exposure = "exposure",
  type_agg = c("equal_exposure", "equal_range"),
  recalib = FALSE,
  ret = c("plot", "data"),
  ...
) {
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  if (length(pred) < 2L) {
    cli::cli_abort(
      "{.arg pred} must contain at least two prediction column names."
    )
  }

  # Defensive copy — never mutate caller data
  dt <- data.table::copy(data.table::as.data.table(data))

  # Optional recalibration — scale each pred to match obs mean.
  # Use data.table::set() rather than [[<- to avoid the shallow-copy warning
  # that [[<- triggers when modifying a data.table column by reference.
  if (recalib) {
    obs_mean <- mean(dt[[obs]], na.rm = TRUE)
    for (p in pred) {
      scale <- obs_mean / mean(dt[[p]], na.rm = TRUE)
      data.table::set(dt, j = p, value = dt[[p]] * scale)
    }
  }

  list_of_plots <- list()

  # For every ordered pair (base, challenger)
  for (base in pred) {
    for (challenger in pred[pred != base]) {
      ratio_name <- paste0(challenger, " / ", base)

      # Ratio of challenger to base — rounded to 7 sig figs to suppress
      # floating-point noise. signif() keeps the column numeric so apply_binning
      # treats it as continuous; sig_dig() would return character and cause
      # apply_binning to skip binning entirely.
      dt[, (ratio_name) := signif(dt[[challenger]] / dt[[base]], 7L)]

      if (ret == "plot") {
        p <- one_way(
          data = dt,
          var = ratio_name,
          obs = c(obs, challenger, base),
          exposure = exposure,
          type_agg = type_agg,
          bins = bins
        )
        list_of_plots[[ratio_name]] <- p
      }
    }
  }

  switch(ret, plot = list_of_plots, data = dt)
}


#' @rdname sami
#' @method sami list
#'
#' @param data         A list of `modelblueprint` objects. Must have length
#'                     2 or more. All blueprints must share the same `y_name`,
#'                     `expo_name`, and training data structure.
#' @param set          `[character(1)]` Which dataset to use from the first
#'                     blueprint: `"train"`, `"test"`, or `"holdout"`.
#'                     Default `"train"`.
#' @param bins         `[integer(1)]` Number of bins. Default `20L`.
#' @param type_agg     `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @param recalib      `[logical(1)]` Recalibrate predictions. Default `FALSE`.
#' @param pred_names   `[character]` Optional vector of names for prediction
#'                     columns. Length must match `length(data)`. When `NA`,
#'                     names are derived from `model_display_name`.
#' @param ret          `[character(1)]` `"plot"` or `"data"`.
#' @param ...          Passed to the default method.
#'
#' @return A named list of plotly objects or a data.table.
#'
#' @examples
#' \donttest{
#' mb1 <- modelblueprint(model = lm(mpg ~ wt, mtcars), train = mtcars,
#'                        y_name = "mpg", model_display_name = "lm_wt")
#' mb2 <- modelblueprint(model = lm(mpg ~ hp, mtcars), train = mtcars,
#'                        y_name = "mpg", model_display_name = "lm_hp")
#' sami(list(mb1, mb2), set = "train", bins = 10)
#' }
#' @export
sami.list <- function(
  data,
  set = c("train", "test", "holdout"),
  bins = 20L,
  type_agg = c("equal_exposure", "equal_range"),
  recalib = FALSE,
  pred_names = NA_character_,
  ret = c("plot", "data"),
  ...
) {
  set <- match.arg(set)
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  if (length(data) < 2L) {
    cli::cli_abort(
      "{.arg data} must be a list of at least two {.cls modelblueprint} objects."
    )
  }

  # Validate all elements are modelblueprint
  is_mb <- vapply(data, function(x) S7_inherits(x, modelblueprint), logical(1L))
  if (!all(is_mb)) {
    cli::cli_abort(
      "All elements of {.arg data} must be {.cls modelblueprint} objects."
    )
  }

  # Get dataset from first blueprint
  df <- prop(data[[1L]], set)
  if (is.null(df)) {
    cli::cli_abort(
      "modelblueprint {.arg @{set}} is NULL in the first blueprint."
    )
  }

  df <- as.data.frame(df)

  # Resolve prediction column names
  if (
    length(pred_names) != length(data) ||
      all(is.na(pred_names))
  ) {
    pred_names <- vapply(
      data,
      function(mb) {
        nm <- mb@model_display_name
        if (is.na(nm) || !nzchar(nm)) {
          cli::cli_abort(c(
            "All {.cls modelblueprint} objects must have {.arg model_display_name} set.",
            i = "Or supply {.arg pred_names} explicitly."
          ))
        }
        paste0("pred_", nm)
      },
      character(1L)
    )
  }

  # Generate predictions — only where column doesn't already exist
  for (i in seq_along(data)) {
    col <- pred_names[i]
    if (!col %in% names(df)) {
      df[[col]] <- predict.modelblueprint(data[[i]], df)
    }
  }

  # Resolve exposure
  exposure <- resolve_exposure(data[[1L]], df)
  if (exposure == "vec_of_ones") {
    df[[".exposure_ones"]] <- 1L
    exposure <- ".exposure_ones"
  }

  sami.default(
    df,
    obs = data[[1L]]@y_name,
    pred = pred_names,
    bins = bins,
    exposure = exposure,
    type_agg = type_agg,
    recalib = recalib,
    ret = ret,
    ...
  )
}
