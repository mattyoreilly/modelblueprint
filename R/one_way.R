# =============================================================================
# one_way.R
# =============================================================================

# Suppress R CMD check NOTEs for data.table's non-standard evaluation.
utils::globalVariables(c(".var", ".w", ".split", ".x_bin", ".expo", "."))

#' Create a one-way analysis plot
#'
#' Bins a feature variable, computes exposure-weighted means of one or more
#' observed variables per bin, and returns a dual-axis plotly chart (bars =
#' exposure, lines = weighted means). Optionally splits by a second variable.
#'
#' Column name arguments (`var`, `obs`, `exposure`, `split`) accept both bare
#' (unquoted) names and strings, so `one_way(df, wt, mpg)` and
#' `one_way(df, "wt", "mpg")` are equivalent.
#'
#' @param data       A data frame or data.table. Must contain all columns
#'                   referenced by other arguments.
#' @param var        Column to plot on the x-axis. Bare name or string.
#' @param obs        One or more columns to summarise on the y-axis (right
#'                   axis). Bare name, `c(a, b)`, or character vector.
#'                   Default `"target"`.
#' @param exposure   Column of exposure weights. If the column does not exist
#'                   in `data`, every row is given weight 1. Bare name or
#'                   string. Default `"exposure"`.
#' @param split      Optional column to split lines by. Bare name, string, or
#'                   `NA` / `NULL` for no split. Default `NA`.
#' @param bins       `[integer(1)]` Number of equal-exposure bins for numeric
#'                   variables with more than `bins` unique values. Default 35.
#' @param time_unit  `[character(1)]` For Date / POSIXct variables, the width
#'                   of each bin. Passed directly to [base::cut.POSIXt()], so
#'                   any string it accepts works: `"month"`, `"week"`,
#'                   `"2 weeks"`, `"12 hours"`, `"quarter"`, `"year"`, etc.
#'                   Ignored for non-date columns. Default `NA` (no date
#'                   binning — dates are shown as individual values).
#' @param type_agg   `[character(1)]` Binning strategy for numeric variables:
#'                   `"equal_exposure"` (default) or `"equal_range"`.
#' @param ret        `[character(1)]` `"plot"` (default) returns a plotly
#'                   object; `"data"` returns the aggregated data.table.
#'
#' @return A plotly object, or a data.table when `ret = "data"`, or `NULL`
#'         with a warning if the plot cannot be produced.
#'
#' @examples
#' \dontrun{
#' # bare names
#' one_way(mtcars, wt, mpg, bins = 10)
#' one_way(mtcars, cyl, c(mpg, hp), split = am)
#'
#' # strings (equivalent)
#' one_way(mtcars, var = "wt", obs = "mpg", bins = 10)
#' one_way(mtcars, var = "cyl", obs = c("mpg", "hp"), split = "am")
#' }
#'
#' @param data A `data.frame` or `data.table`.
#' @param ... Arguments passed to methods.
#' @export
one_way <- function(data, ...) UseMethod("one_way")

#' @rdname one_way
#' @method one_way default
#' @export
one_way.default <- function(
  data,
  var,
  obs = "target",
  exposure = "exposure",
  split = NA_character_,
  bins = 35L,
  time_unit = NA_character_,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
) {
  # --- NSE: accept bare names or strings for column arguments ----------------
  # enexpr() captures the expression before the promise is forced.
  # * Bare name:    one_way(df, wt)         -> "wt"
  # * String:       one_way(df, "wt")       -> "wt"
  # * Variable:     one_way(df, var = col)  -> forces promise -> character
  # * c(a, b):      one_way(df, c(mpg, hp)) -> c("mpg", "hp")
  # * NULL/NA split coerced to NA_character_.
  # If a bare-name symbol is not a column in data, the promise is forced so
  # programmatic callers (e.g. one_way(df, var = col_vec[j])) still work.

  var_expr <- rlang::enexpr(var)
  var <- if (is.character(var_expr)) {
    var_expr
  } else if (is.symbol(var_expr)) {
    sym <- rlang::as_name(var_expr)
    if (sym %in% names(data)) sym else var
  } else {
    var # complex expr (e.g. vars[[j]]) — force promise
  }

  obs_expr <- rlang::enexpr(obs)
  obs <- if (is.character(obs_expr)) {
    obs_expr
  } else if (
    rlang::is_call(obs_expr) &&
      identical(rlang::call_name(obs_expr), "c")
  ) {
    # Resolve each arg of c(): string literal -> kept; bare name -> column
    # lookup. If ANY arg is a symbol that isn't a column (i.e. it's a local
    # variable holding a string), fall back to forcing the promise so that
    # programmatic callers like sami() still work.
    args <- rlang::call_args(obs_expr)
    resolved <- vapply(
      args,
      function(a) {
        if (is.character(a)) {
          return(a)
        }
        if (is.symbol(a)) {
          nm <- rlang::as_name(a)
          if (nm %in% names(data)) return(nm)
        }
        NA_character_
      },
      character(1L)
    )
    if (anyNA(resolved)) obs else resolved # force promise if any non-column
  } else if (is.symbol(obs_expr)) {
    sym <- rlang::as_name(obs_expr)
    if (sym %in% names(data)) sym else obs
  } else {
    obs
  }

  exposure_expr <- rlang::enexpr(exposure)
  exposure <- if (is.character(exposure_expr)) {
    exposure_expr
  } else if (is.symbol(exposure_expr)) {
    sym <- rlang::as_name(exposure_expr)
    if (sym %in% names(data)) sym else exposure
  } else {
    exposure
  }

  split_expr <- rlang::enexpr(split)
  split <- if (is.null(split_expr) || identical(split_expr, quote(NULL))) {
    NA_character_
  } else if (is.symbol(split_expr)) {
    sym <- rlang::as_name(split_expr)
    if (sym %in% names(data)) sym else split
  } else {
    split # NA_character_, string, or complex expr
  }
  # ---------------------------------------------------------------------------

  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  # -- Input validation --------------------------------------------------------
  validate_inputs(data, var, obs, exposure, split, bins)

  # -- Coerce to data.table (copy - never mutate caller's data) ----------------
  dt <- data.table::as.data.table(data)

  # -- Resolve exposure --------------------------------------------------------
  # If the exposure column doesn't exist, add a unit-weight column so all
  # downstream code can treat exposure as always present.
  expo_col <- if (exposure %in% names(dt)) exposure else ".expo"
  if (expo_col == ".expo") {
    dt[, .expo := 1L]
  }

  # -- Guard: too many levels for a non-numeric column -------------------------
  # Bypass the guard for Date/datetime columns when time_unit is set — the
  # binning step will reduce arbitrarily many unique dates to a manageable
  # number of labelled groups.
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

  # -- Aggregate ---------------------------------------------------------------
  agg <- aggregate_one_way(
    dt,
    var,
    obs,
    expo_col,
    split,
    bins,
    type_agg,
    time_unit
  )

  if (ret == "data") {
    # Rename internal .x_bin back to the original variable name for the user
    data.table::setnames(agg, ".x_bin", var)
    return(agg)
  }

  # -- Plot ---------------------------------------------------------------------
  has_split <- !is.na(split) && data.table::uniqueN(agg$split) > 1L
  # Note: bin labels live in agg$.x_bin (never "x") to avoid colliding with
  # an obs column the user may have named "x".

  if (has_split) {
    plot_one_way_split(agg, var, obs, split)
  } else {
    plot_one_way_simple(agg, var, obs)
  }
}


# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

validate_inputs <- function(data, var, obs, exposure, split, bins) {
  if (!is.data.frame(data) && !data.table::is.data.table(data)) {
    cli::cli_abort("{.arg data} must be a data frame or data.table.")
  }
  assert_col_exists(data, var, "`var`")
  assert_col_exists(data, obs, "`obs`")
  if (!is.na(split)) {
    assert_col_exists(data, split, "`split`")
  }

  if (!is.numeric(bins) || length(bins) != 1L || bins < 2L) {
    cli::cli_abort("{.arg bins} must be a single integer >= 2.")
  }
}


# -----------------------------------------------------------------------------
# Binning
# -----------------------------------------------------------------------------
# The numeric binning primitives (bin_equal_exposure, bin_equal_range,
# bin_numeric, remap_sorted_bins) and assert_col_exists live in binning.R so
# they can be shared with pdp() and shap().

#' Bin the named column of a data.table in place
#'
#' Replaces `dt[[col]]` with character bin labels. Returns the data.table
#' unchanged when the column is categorical or low-cardinality. Handles
#' Date/datetime columns when `time_unit` is supplied.
#'
#' @param dt        A data.table.
#' @param col       `[character(1)]` Name of the column to bin in place.
#' @param bins      `[integer(1)]` Number of bins.
#' @param type_agg  `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @param time_unit `[character(1)]` Optional date bin width for Date/POSIXct
#'                  columns (passed to [base::cut.POSIXt()]).
#' @keywords internal
apply_binning <- function(dt, col, bins, type_agg, time_unit = NA_character_) {
  v <- dt[[col]]

  # --- Date / datetime with explicit time_unit --------------------------------
  # Use cut.POSIXt for date-aware binning. Convert Date -> POSIXct so the same
  # code path handles both and all time_unit strings (including "12 hours") work.
  is_date <- inherits(v, "Date")
  is_datetime <- inherits(v, c("POSIXct", "POSIXlt"))
  if ((is_date || is_datetime) && !is.na(time_unit) && nzchar(time_unit)) {
    v_posix <- as.POSIXct(v)
    binned_chr <- as.character(cut(v_posix, breaks = time_unit))
    # Strip the redundant " 00:00:00" suffix when all labels fall at midnight
    # (e.g. monthly or daily cuts of Date data).
    non_na_lbl <- binned_chr[!is.na(binned_chr)]
    if (length(non_na_lbl) > 0L && all(endsWith(non_na_lbl, " 00:00:00"))) {
      binned_chr <- sub(" 00:00:00$", "", binned_chr)
    }
    data.table::set(dt, j = col, value = binned_chr)
    return(dt)
  }

  # Skip binning for categoricals or low-cardinality numerics
  is_categorical <- inherits(
    v,
    c("factor", "character", "POSIXct", "POSIXt", "Date")
  )
  # Skip binning only when unique values <= bins - at that point binning adds
  # nothing. The old max(50, bins) threshold was too aggressive and prevented
  # continuous columns like mtcars$wt (32 unique values) from being binned.
  is_low_card <- data.table::uniqueN(v, na.rm = TRUE) <= bins

  if (is_categorical || is_low_card) {
    return(dt)
  }

  # bin_numeric() handles strategy selection and remaps labels back onto the
  # original (unsorted, NA-preserving) row order.
  bin_labels <- bin_numeric(v, bins, type_agg)$labels

  data.table::set(dt, j = col, value = bin_labels)
  dt
}


# -----------------------------------------------------------------------------
# Aggregation
# -----------------------------------------------------------------------------

#' Aggregate data for a one-way plot
#'
#' @return data.table with columns: x, split, <obs columns>, exposure
#' @keywords internal
aggregate_one_way <- function(
  dt,
  var,
  obs,
  expo_col,
  split,
  bins,
  type_agg,
  time_unit = NA_character_
) {
  # Select only the columns we need - critical for large datasets
  keep <- unique(c(var, obs, expo_col, if (!is.na(split)) split))
  dt <- dt[, .SD, .SDcols = keep]

  # Date / datetime: convert to character strings immediately, while the class
  # is still intact. data.table's subsequent setnames / subsetting can silently
  # drop class attributes, causing as.character() later to emit raw epoch-day
  # numbers instead of "YYYY-MM-DD" labels.
  if (inherits(dt[[var]], c("Date", "POSIXct", "POSIXlt"))) {
    has_time_unit <- !is.na(time_unit) && nzchar(time_unit)
    if (has_time_unit) {
      # Bin into calendar periods via cut.POSIXt
      v_posix <- as.POSIXct(dt[[var]])
      binned_chr <- as.character(cut(v_posix, breaks = time_unit))
      non_na_lbl <- binned_chr[!is.na(binned_chr)]
      if (length(non_na_lbl) > 0L && all(endsWith(non_na_lbl, " 00:00:00"))) {
        binned_chr <- sub(" 00:00:00$", "", binned_chr)
      }
      dt[, (var) := binned_chr]
    } else {
      # No time_unit: just lock in the human-readable string now
      dt[, (var) := as.character(dt[[var]])]
    }
  }

  # Rename var/exposure/split to dot-prefixed internal names.
  # Dot-prefixed names cannot collide with any obs column the user would
  # typically supply (e.g. obs = "x", obs = "split", obs = "exposure").
  data.table::setnames(dt, c(var, expo_col), c(".var", ".w"))
  if (!is.na(split)) {
    data.table::setnames(dt, split, ".split")
  } else {
    dt[, .split := "__none__"]
  }

  # Coerce integer -> numeric for clean binning arithmetic
  if (is.integer(dt$.var)) {
    dt[, .var := as.numeric(.var)]
  }

  # Bin high-cardinality numeric split variable into 10 groups
  if (
    !is.na(split) &&
      is.numeric(dt$.split) &&
      data.table::uniqueN(dt$.split, na.rm = TRUE) > 20L
  ) {
    dt[,
      .split := as.character(
        cut(.split, breaks = 10L, include.lowest = TRUE, dig.lab = 7L)
      )
    ]
  }

  # Identify NA rows before any type coercion
  na_mask <- is.na(dt$.var)
  n_na <- sum(na_mask)
  na_rows <- dt[na_mask]
  dt_clean <- dt[!na_mask]

  if (n_na > 0L) {
    message(sprintf(
      "one_way: %d NA value(s) in '%s' moved to trailing 'NA' category.",
      n_na,
      var
    ))
  }

  # Bin the internal ".var" column directly. Force to character immediately
  # after binning so cut()'s factor output never survives into rbindlist as a
  # type that produces NA_character_.
  dt_clean <- apply_binning(dt_clean, ".var", bins, type_agg, time_unit)
  dt_clean[, .var := as.character(.var)]

  # Recombine - assign sentinel string AFTER rbindlist using a logical mask
  # so there is no factor vs character type conflict across the two tables.
  dt_all <- if (n_na > 0L) {
    na_rows[, .var := as.character(.var)] # coerce to char before rbindlist
    na_rows[, .var := NA_character_]
    dt_combined <- data.table::rbindlist(
      list(dt_clean, na_rows),
      use.names = TRUE
    )
    dt_combined[is.na(.var), .var := "NA"]
    dt_combined
  } else {
    dt_clean
  }

  # Exposure-weighted mean per (x-bin, split group).
  # Group by ".x_bin" (dot-prefix) so the grouping key cannot shadow any
  # obs column; rename to public "x" only after aggregation is complete.
  agg <- dt_all[,
    {
      w_total <- sum(.w, na.rm = TRUE)
      obs_means <- lapply(.SD, function(col) {
        sum(col * .w, na.rm = TRUE) / w_total
      })
      c(obs_means, list(exposure = w_total))
    },
    by = .(.x_bin = as.character(.var), .split),
    .SDcols = obs
  ]

  # Rename .split -> split for the public output; keep .x_bin as-is so it
  # never collides with an obs column named "x".
  data.table::setnames(agg, ".split", "split")

  # Apply smart x-axis ordering on .x_bin
  x_levels <- smart_level_order(unique(agg$.x_bin))
  agg[, .x_bin := factor(.x_bin, levels = x_levels)]
  data.table::setorder(agg, .x_bin, split)
  agg[, .x_bin := as.character(.x_bin)]

  agg
}


# -----------------------------------------------------------------------------
# Plot: no split
# -----------------------------------------------------------------------------

#' @keywords internal
plot_one_way_simple <- function(agg, var, obs) {
  # Bin labels live in .x_bin - never renamed to "x" to avoid colliding with
  # an obs column the caller may have named "x".
  x_levels <- smart_level_order(unique(agg$.x_bin))
  agg_df <- as.data.frame(agg)

  # Colours and symbols match the original plot_oneway exactly:
  # purple lead, then Paired palette; square for first obs, triangle-up for rest
  colours <- c(
    "#9900cc",
    RColorBrewer::brewer.pal(max(3L, length(obs)), "Paired")
  )
  symbols <- c("square", "triangle-up")

  p <- plotly::plot_ly(agg_df)

  # Observed lines (right axis) - added first so they sit above the bars
  for (i in seq_along(obs)) {
    col <- obs[i]
    colour <- colours[i]
    symbol <- symbols[min(i, length(symbols))]
    y_vals <- as.numeric(agg_df[[col]])
    grand_mean <- sum(y_vals * agg_df$exposure, na.rm = TRUE) /
      sum(agg_df$exposure, na.rm = TRUE)

    # Percentage difference vs first obs - mirrors original set$error logic
    if (i > 1L) {
      y_ref <- as.numeric(agg_df[[obs[1L]]])
      err <- paste0(", ", round((y_vals - y_ref) / y_ref, 3L) * 100, "%")
    } else {
      err <- rep("", nrow(agg_df))
    }

    p <- plotly::add_trace(
      p,
      x = ~.x_bin,
      y = y_vals,
      yaxis = "y2",
      type = "scatter",
      mode = "lines+markers",
      name = col,
      line = list(color = colour),
      marker = list(color = colour, symbol = symbol),
      hoverinfo = "text",
      hovertext = paste0(col, ": ", sig_dig(y_vals, 7L), " ", err)
    )

    # Grand-mean reference line - dashed, same colour
    p <- plotly::add_trace(
      p,
      x = x_levels,
      y = rep(grand_mean, length(x_levels)),
      yaxis = "y2",
      type = "scatter",
      mode = "lines",
      name = paste(col, "Mean"),
      line = list(color = colour),
      hoverinfo = "text",
      hovertext = paste0("Mean ", col, ": ", sig_dig(grand_mean, 7L))
    )
  }

  # Yellow exposure bars (left axis) - identical to original
  p <- plotly::add_trace(
    p,
    x = ~.x_bin,
    y = ~exposure,
    yaxis = "y",
    type = "bar",
    orientation = "v",
    name = "Exposure",
    marker = list(color = "#ffff00"),
    hoverinfo = "text",
    hovertext = paste0(
      "Exposure: ",
      agg_df$.x_bin,
      " = ",
      sig_dig(agg_df$exposure, 7L)
    )
  )

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
        title = "Observed"
      ),
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
plot_one_way_split <- function(agg, var, obs, split) {
  x_levels <- smart_level_order(unique(agg$.x_bin))
  groups <- sort(unique(agg$split[agg$split != "__none__"]))
  n_groups <- length(groups)

  # Paired palette - matches original plot_oneway_by exactly
  pal <- if (n_groups >= 3L) {
    RColorBrewer::brewer.pal(n_groups, "Paired")
  } else {
    RColorBrewer::brewer.pal(3L, "Paired")[seq_len(n_groups)]
  }
  symbols <- c("square", "circle", "diamond", "pentagon", "cross")

  p <- plotly::plot_ly()

  # Observed lines - one trace per (obs x split group)
  # Use explicit marker colours (not color = ~split) to avoid plotly adding
  # a gradient colourbar legend.
  for (i in seq_along(obs)) {
    col <- obs[i]
    symbol <- symbols[((i - 1L) %% length(symbols)) + 1L]

    for (k in seq_along(groups)) {
      grp <- groups[k]
      sub <- as.data.frame(agg[agg$split == grp, ])
      colour <- pal[k]
      y_vals <- as.numeric(sub[[col]])

      p <- plotly::add_trace(
        p,
        data = sub,
        x = ~.x_bin,
        y = y_vals,
        yaxis = "y2",
        name = paste(col, grp),
        type = "scatter",
        mode = "lines+markers",
        line = list(color = colour),
        marker = list(
          color = colour,
          size = 8,
          symbol = symbol,
          line = list(color = "rgb(0,0,0)", width = 2)
        ),
        hoverinfo = "text",
        hovertext = paste0(col, " (", grp, "): ", sig_dig(y_vals, 7L))
      )
    }
  }

  # Exposure bars - one per split group, explicit colour per group
  # No color = ~split mapping so plotly never adds a gradient colourbar.
  for (k in seq_along(groups)) {
    grp <- groups[k]
    sub <- as.data.frame(agg[agg$split == grp, ])
    colour <- pal[k]

    p <- plotly::add_trace(
      p,
      data = sub,
      x = ~.x_bin,
      y = ~exposure,
      yaxis = "y",
      type = "bar",
      name = paste("Exposure", grp),
      orientation = "v",
      showlegend = FALSE,
      marker = list(color = colour, opacity = 0.4),
      hoverinfo = "text",
      hovertext = paste0("Exposure (", grp, "): ", sig_dig(sub$exposure, 7L))
    )
  }

  p %>%
    plotly::layout(
      barmode = "group",
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
        title = "Target"
      ),
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


# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

#' Sort x-axis labels: numeric intervals first, dates chronologically, then
#' categoricals alphabetically, NA last.
#' @keywords internal
smart_level_order <- function(x) {
  if (length(x) == 0L) {
    return(x)
  }
  na_label <- x[x == "NA"]
  non_na <- x[x != "NA"]

  # Date-like strings start with YYYY-MM-DD. ISO format is lexicographically
  # identical to chronological order, so plain sort() is correct and fast.
  is_date_str <- grepl("^\\d{4}-\\d{2}-\\d{2}", non_na)

  # Extract leading number from interval/numeric labels (e.g. "(1.5,3.2]" -> 1.5).
  # Exclude date-like strings so "2023-01-15" isn't mistaken for the number 2023.
  leading <- suppressWarnings(as.numeric(
    sub("^[\\[\\(]?(-?[0-9]*\\.?[0-9]+).*", "\\1", trimws(non_na), perl = TRUE)
  ))
  is_num <- !is.na(leading) & !is_date_str

  c(
    non_na[is_num][order(leading[is_num])], # numeric/interval bins
    sort(non_na[is_date_str]), # date strings: alpha == chrono
    sort(non_na[!is_num & !is_date_str]), # other categoricals
    na_label
  )
}

#' Format numbers to n significant digits
#' @keywords internal
sig_dig <- function(x, n = 7L) {
  formatC(signif(x, digits = n), digits = n, format = "fg", flag = "#")
}
