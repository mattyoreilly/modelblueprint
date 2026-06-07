utils::globalVariables("target")

#' NSE wrapper for one_way
#'
#' Allows bare (unquoted) column names to be passed instead of strings.
#' Delegates to [one_way()] after resolving names.
#'
#' @param data     A data frame or data.table.
#' @param var      Bare column name for the x-axis variable.
#' @param obs      Bare column name(s) to summarise. Wrap multiple in `c()`,
#'                 e.g. `c(mpg, hp)`. Default `target`.
#' @param exposure Bare column name for exposure weights. Default `exposure`.
#' @param split    Bare column name to split lines by. Omit or pass `NULL`
#'                 for no split.
#' @param bins     `[integer(1)]` Number of bins. Default 35.
#' @param type_agg `[character(1)]` `"equal_exposure"` (default) or
#'                 `"equal_range"`.
#' @param ret      `[character(1)]` `"plot"` (default) or `"data"`.
#' @param ...      Additional arguments passed to [one_way()].
#'
#' @return See [one_way()].
#'
#' @examples
#' \dontrun{
#' one_way_nse(mtcars, wt, mpg, bins = 10)
#' one_way_nse(mtcars, cyl, c(mpg, hp), split = am)
#' one_way_nse(loans_df, loan_amount, c(default_rate, loss_rate),
#'             exposure = n_accounts, split = risk_band)
#' }
#'
#' @export
one_way_nse <- function(
  data,
  var,
  obs = target,
  exposure = exposure,
  split = NULL,
  bins = 35L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
) {
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  # -- Resolve var -------------------------------------------------------------
  var_str <- rlang::as_name(rlang::ensym(var))

  # -- Resolve obs (single bare name or c(a, b, c)) ---------------------------
  obs_expr <- rlang::enexpr(obs)
  obs_str <- if (
    rlang::is_call(obs_expr) &&
      identical(rlang::call_name(obs_expr), "c")
  ) {
    vapply(rlang::call_args(obs_expr), rlang::as_name, character(1L))
  } else {
    rlang::as_name(obs_expr)
  }

  # -- Resolve exposure --------------------------------------------------------
  exposure_str <- rlang::as_name(rlang::ensym(exposure))

  # -- Resolve split (NULL => NA; bare name => string) -------------------------
  split_expr <- rlang::enexpr(split)
  split_str <- if (is.null(split_expr) || identical(split_expr, quote(NULL))) {
    NA_character_
  } else {
    rlang::as_name(split_expr)
  }

  one_way(
    data,
    var = var_str,
    obs = obs_str,
    exposure = exposure_str,
    split = split_str,
    bins = bins,
    type_agg = type_agg,
    ret = ret,
    ...
  )
}
