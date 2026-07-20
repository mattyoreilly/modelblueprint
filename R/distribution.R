# =============================================================================
# distribution.R
# =============================================================================


#' Plot the distribution of the target variable
#'
#' Bins the target variable and plots the total exposure per bin as a bar
#' chart — an exposure-weighted distribution of the target. Shares its
#' argument conventions, binning, NA handling, split behaviour, and plotly
#' styling with [one_way()]; the only difference is that the target itself is
#' the x-axis variable, so there is no `obs` argument.
#'
#' Column name arguments (`var`, `exposure`, `split`) accept both bare
#' (unquoted) names and strings, so `distribution(df, mpg)` and
#' `distribution(df, "mpg")` are equivalent.
#'
#' @param data       A data frame or data.table. Must contain all columns
#'                   referenced by other arguments.
#' @param var        Target column whose distribution to plot. Bare name or
#'                   string. Default `"target"`.
#' @param exposure   Column of exposure weights. If the column does not exist
#'                   in `data`, every row is given weight 1. Bare name or
#'                   string. Default `"exposure"`.
#' @param split      Optional column to group bars by. Bare name, string, or
#'                   `NA` / `NULL` for no split. Default `NA`.
#' @param bins       `[integer(1)]` Number of equal-exposure bins for numeric
#'                   targets with more than `bins` unique values. Default 35.
#' @param time_unit  `[character(1)]` For Date / POSIXct targets, the width of
#'                   each bin (passed to [base::cut.POSIXt()]). Default `NA`.
#' @param type_agg   `[character(1)]` Binning strategy for numeric targets:
#'                   `"equal_exposure"` (default) or `"equal_range"`.
#' @param ret        `[character(1)]` `"plot"` (default) returns a plotly
#'                   object; `"data"` returns the aggregated data.table.
#' @param verbose    `[logical(1)]` Report how many NA values of `var` were
#'                   moved to the trailing `"NA"` category? Default `FALSE`.
#' @param ...        Arguments passed to methods.
#'
#' @return A plotly object, or a data.table when `ret = "data"`, or `NULL`
#'         with a warning if the plot cannot be produced.
#'
#' @examples
#' \donttest{
#' distribution(mtcars, mpg, bins = 10)
#' distribution(mtcars, var = "mpg", split = "am")
#' }
#'
#' @export
distribution <- function(data, ...) UseMethod("distribution")

#' @rdname distribution
#' @method distribution default
#' @export
distribution.default <- function(
  data,
  var = "target",
  exposure = "exposure",
  split = NA_character_,
  bins = 35L,
  time_unit = NA_character_,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  verbose = FALSE,
  ...
) {
  # --- NSE: accept bare names or strings, same semantics as one_way() --------
  # resolve_bare_name() forces the `fallback` promise only when the captured
  # expression is neither a string nor a column name, so programmatic callers
  # (e.g. distribution(df, var = cols[j])) still work.
  var <- resolve_bare_name(rlang::enexpr(var), data, var)
  exposure <- resolve_bare_name(rlang::enexpr(exposure), data, exposure)

  split_expr <- rlang::enexpr(split)
  split <- if (is.null(split_expr) || identical(split_expr, quote(NULL))) {
    NA_character_
  } else {
    resolve_bare_name(split_expr, data, split)
  }
  # ---------------------------------------------------------------------------

  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  # obs = var: the target column doubles as its own obs, so one_way's
  # validation applies unchanged.
  validate_inputs(data, var, var, exposure, split, bins)

  # Narrow before copying, as in one_way() — never mutate the caller's data.
  keep <- unique(c(
    var,
    if (exposure %in% names(data)) exposure,
    if (!is.na(split)) split
  ))
  narrow <- if (data.table::is.data.table(data)) {
    data[, keep, with = FALSE]
  } else {
    data[keep]
  }
  dt <- data.table::copy(data.table::as.data.table(narrow))

  expo_col <- if (exposure %in% names(dt)) exposure else ".expo"
  if (expo_col == ".expo") {
    dt[, .expo := 1L]
  }

  # Guard: too many levels for a non-numeric target (same rule as one_way)
  n_unique <- data.table::uniqueN(dt[[var]], na.rm = TRUE)
  is_date_col <- inherits(dt[[var]], c("Date", "POSIXct", "POSIXlt"))
  has_time_unit <- !is.na(time_unit) && nzchar(time_unit)
  if (
    n_unique > 2000L &&
      !is.numeric(dt[[var]]) &&
      !(is_date_col && has_time_unit)
  ) {
    cli::cli_warn(
      "{.arg {var}} has {n_unique} unique values (max 2,000 for non-numeric). Skipping."
    )
    return(NULL)
  }

  # Reuse one_way's aggregation for binning, NA category, split handling, and
  # x-axis ordering. ".one" is a dummy obs column (weighted mean of 1 is 1)
  # so the machinery runs for any target type; only the exposure sums matter.
  dt[, .one := 1]
  agg <- aggregate_one_way(
    dt,
    var,
    ".one",
    expo_col,
    split,
    bins,
    type_agg,
    time_unit,
    verbose = verbose
  )
  agg[, .one := NULL]

  if (ret == "data") {
    data.table::setnames(agg, ".x_bin", var)
    return(agg[])
  }

  has_split <- !is.na(split) && data.table::uniqueN(agg$split) > 1L
  if (has_split) {
    plot_distribution_split(agg, var, split)
  } else {
    plot_distribution_simple(agg, var)
  }
}


# -----------------------------------------------------------------------------
# NSE helper
# -----------------------------------------------------------------------------

#' Resolve a captured column argument to a column name string
#'
#' String -> itself; bare name that is a column of `data` -> that name;
#' anything else forces the `fallback` promise (default string, local
#' variable, or complex expression).
#' @keywords internal
resolve_bare_name <- function(expr, data, fallback) {
  if (is.character(expr)) {
    return(expr)
  }
  if (is.symbol(expr)) {
    nm <- rlang::as_name(expr)
    if (nm %in% names(data)) {
      return(nm)
    }
  }
  fallback
}


# -----------------------------------------------------------------------------
# Plot: no split
# -----------------------------------------------------------------------------

#' @keywords internal
plot_distribution_simple <- function(agg, var) {
  x_levels <- smart_level_order(unique(agg$.x_bin))
  agg_df <- as.data.frame(agg)
  pct <- agg_df$exposure / sum(agg_df$exposure) * 100

  plotly::plot_ly(agg_df) |>
    plotly::add_trace(
      x = ~.x_bin,
      y = ~exposure,
      type = "bar",
      orientation = "v",
      name = "Exposure",
      marker = list(color = "#ffff00"),
      hoverinfo = "text",
      hovertext = paste0(
        "Exposure: ",
        agg_df$.x_bin,
        " = ",
        sig_dig(agg_df$exposure, 7L),
        " (",
        round(pct, 1L),
        "%)"
      )
    ) |>
    plotly::layout(
      xaxis = list(
        title = var,
        categoryorder = "array",
        categoryarray = x_levels
      ),
      yaxis = list(title = "Exposure", showgrid = TRUE, autorange = TRUE),
      legend = list(x = 1.15, y = 0.5),
      margin = list(t = 25, b = 100, l = 50, r = 50),
      hovermode = "x",
      plot_bgcolor = "rgba(0,0,0,0)",
      paper_bgcolor = "rgba(0,0,0,0)"
    )
}


# -----------------------------------------------------------------------------
# Plot: with split
# -----------------------------------------------------------------------------

#' @keywords internal
plot_distribution_split <- function(agg, var, split) {
  x_levels <- smart_level_order(unique(agg$.x_bin))
  groups <- sort(unique(agg$split[agg$split != "__none__"]))
  n_groups <- length(groups)

  # Paired palette — matches one_way's split colours
  pal <- if (n_groups >= 3L) {
    RColorBrewer::brewer.pal(n_groups, "Paired")
  } else {
    RColorBrewer::brewer.pal(3L, "Paired")[seq_len(n_groups)]
  }

  p <- plotly::plot_ly()
  for (k in seq_along(groups)) {
    grp <- groups[k]
    sub <- as.data.frame(agg[agg$split == grp, ])
    # Percentage within each group so distributions of different-sized
    # groups remain comparable in the hover text.
    pct <- sub$exposure / sum(sub$exposure) * 100

    p <- plotly::add_trace(
      p,
      data = sub,
      x = ~.x_bin,
      y = ~exposure,
      type = "bar",
      orientation = "v",
      name = grp,
      marker = list(color = pal[k]),
      hoverinfo = "text",
      hovertext = paste0(
        "Exposure (",
        grp,
        "): ",
        sig_dig(sub$exposure, 7L),
        " (",
        round(pct, 1L),
        "% of ",
        grp,
        ")"
      )
    )
  }

  p |>
    plotly::layout(
      barmode = "group",
      xaxis = list(
        title = var,
        categoryorder = "array",
        categoryarray = x_levels
      ),
      yaxis = list(title = "Exposure", showgrid = TRUE, autorange = TRUE),
      legend = list(
        x = 1.15,
        y = 0.5,
        title = list(text = paste0("<b>", split, "</b>"))
      ),
      margin = list(t = 25, b = 100, l = 50, r = 50),
      hovermode = "x",
      plot_bgcolor = "rgba(0,0,0,0)",
      paper_bgcolor = "rgba(0,0,0,0)"
    )
}
