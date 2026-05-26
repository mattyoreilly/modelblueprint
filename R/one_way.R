# =============================================================================
# one_way.R
# One-way plot: exposure-weighted means of one or more observed variables
# across bins of a feature variable, with optional split grouping.
#
# Design principles:
#   - data.table for all aggregation (scales to 2M+ rows)
#   - Native plotly for output (dual-axis: bars = exposure, lines = means)
#   - Pure functions - no side effects, no global mutation, no print() calls
#   - Fail fast with informative errors; return NULL on recoverable failures
#   - One function, one responsibility
# =============================================================================

# Suppress R CMD check NOTEs for data.table's non-standard evaluation.
utils::globalVariables(c(".var", ".w", ".split", ".x_bin", ".expo", "var", "."))

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

#' Create a one-way analysis plot
#'
#' Bins a feature variable, computes exposure-weighted means of one or more
#' observed variables per bin, and returns a dual-axis plotly chart (bars =
#' exposure, lines = weighted means). Optionally splits by a second variable.
#'
#' @param data       A data frame or data.table. Must contain all columns
#'                   referenced by other arguments.
#' @param var        `[character(1)]` Column to plot on the x-axis.
#' @param obs        `[character()]` One or more column names to summarise on
#'                   the y-axis (right axis). Default `"target"`.
#' @param exposure   `[character(1)]` Column of exposure weights. If the column
#'                   does not exist in `data`, every row is given weight 1.
#'                   Default `"exposure"`.
#' @param split      `[character(1) | NA]` Optional column to split lines by.
#'                   `NA` (default) produces a single set of lines.
#' @param bins       `[integer(1)]` Number of equal-exposure bins for numeric
#'                   variables with more than `bins` unique values. Default 35.
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
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
) {
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
  n_unique <- data.table::uniqueN(dt[[var]], na.rm = TRUE)
  if (n_unique > 2000L && !is.numeric(dt[[var]])) {
    warning(sprintf(
      "one_way: '%s' has %d unique values (max 2,000 for non-numeric). Skipping.",
      var,
      n_unique
    ))
    return(NULL)
  }

  # -- Aggregate ---------------------------------------------------------------
  agg <- aggregate_one_way(dt, var, obs, expo_col, split, bins, type_agg)

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
    stop("`data` must be a data frame or data.table.", call. = FALSE)
  }
  assert_col_exists(data, var, "`var`")
  assert_col_exists(data, obs, "`obs`")
  if (!is.na(split)) {
    assert_col_exists(data, split, "`split`")
  }

  if (!is.numeric(bins) || length(bins) != 1L || bins < 2L) {
    stop("`bins` must be a single integer >= 2.", call. = FALSE)
  }
}

assert_col_exists <- function(data, cols, arg_name) {
  missing_cols <- setdiff(cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      sprintf(
        "%s column(s) not found in `data`: %s",
        arg_name,
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }
}


# -----------------------------------------------------------------------------
# Binning helpers
# -----------------------------------------------------------------------------

#' Bin a sorted numeric vector into n equal-exposure groups
#' @keywords internal
bin_equal_exposure <- function(x_sorted, bins) {
  n <- length(x_sorted)
  idx <- unique(as.integer(seq(n / bins, n, length.out = bins)))
  breaks <- signif(c(x_sorted[1L], x_sorted[idx]), 7L)
  # unique() AFTER signif() - rounding can re-introduce duplicates if applied before
  breaks <- unique(breaks)
  # Clamp endpoints to actual data range - signif() can push the max break
  # below max(x_sorted), leaving the last element outside the range -> NA
  breaks[1L] <- min(x_sorted)
  breaks[length(breaks)] <- max(x_sorted)
  cut(x_sorted, breaks = breaks, include.lowest = TRUE, dig.lab = 7L)
}

#' Bin a numeric vector into n equal-range groups
#' @keywords internal
bin_equal_range <- function(x, bins) {
  rng <- range(x, na.rm = TRUE)
  spread <- diff(rng)
  mag <- if (is.finite(spread) && spread > 0) {
    floor(log10(spread / bins))
  } else {
    0L
  }
  decimals <- if (mag < 0L) 2L - mag else 0L
  breaks <- round(seq(rng[1L], rng[2L], length.out = bins + 1L), decimals)
  cut(
    x,
    breaks = unique(breaks),
    include.lowest = TRUE,
    dig.lab = max(7L, decimals + 3L)
  )
}

#' Apply binning to the `var` column of a data.table (in-place)
#'
#' Returns the data.table unchanged if `var` is categorical or low-cardinality.
#' @keywords internal
apply_binning <- function(dt, bins, type_agg) {
  v <- dt$var

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

  v_nonmissing <- sort(v[!is.na(v)])

  binned <- suppressWarnings(
    if (type_agg == "equal_range") {
      bin_equal_range(v_nonmissing, bins)
    } else {
      bin_equal_exposure(v_nonmissing, bins)
    }
  )

  # Map bin labels back onto original row order
  # Build a lookup: original value -> bin label (using sorted non-NA positions)
  bin_labels <- rep(NA_character_, length(v))
  non_na_idx <- which(!is.na(v))
  sorted_non_na_idx <- non_na_idx[order(v[non_na_idx])]
  bin_labels[sorted_non_na_idx] <- as.character(binned)

  dt[, var := bin_labels]
  dt
}


# -----------------------------------------------------------------------------
# Aggregation
# -----------------------------------------------------------------------------

#' Aggregate data for a one-way plot
#'
#' @return data.table with columns: x, split, <obs columns>, exposure
#' @keywords internal
aggregate_one_way <- function(dt, var, obs, expo_col, split, bins, type_agg) {
  # Select only the columns we need - critical for large datasets
  keep <- unique(c(var, obs, expo_col, if (!is.na(split)) split))
  dt <- dt[, .SD, .SDcols = keep]

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

  # apply_binning expects a column named "var" - rename temporarily.
  # Force to character immediately after binning so cut()'s factor output
  # never survives into rbindlist as a type that produces NA_character_.
  data.table::setnames(dt_clean, ".var", "var")
  dt_clean <- apply_binning(dt_clean, bins, type_agg)
  dt_clean[, var := as.character(var)]
  data.table::setnames(dt_clean, "var", ".var")

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

#' Sort x-axis labels: numerics / intervals first, then categoricals, NA last
#' @keywords internal
smart_level_order <- function(x) {
  if (length(x) == 0L) {
    return(x)
  }
  leading <- suppressWarnings(as.numeric(
    sub("^[\\[\\(]?(-?[0-9]*\\.?[0-9]+).*", "\\1", trimws(x), perl = TRUE)
  ))
  is_num <- !is.na(leading)
  na_label <- x[x == "NA"]
  c(
    x[is_num][order(leading[is_num])],
    sort(x[!is_num & x != "NA"]),
    na_label
  )
}

#' Make a colour palette of length n, handling n < 3 gracefully
#' @keywords internal
make_palette <- function(n, palette = "Paired") {
  if (n <= 1L) {
    return("#2563eb")
  }
  RColorBrewer::brewer.pal(max(3L, n), palette)[seq_len(n)]
}

#' Convert a hex colour to an rgba() CSS string
#' @keywords internal
hex_to_rgba <- function(hex, alpha = 1) {
  rgb <- grDevices::col2rgb(hex)
  sprintf("rgba(%d,%d,%d,%.2f)", rgb[1L], rgb[2L], rgb[3L], alpha)
}

#' Format numbers to n significant digits
#' @keywords internal
sig_dig <- function(x, n = 7L) {
  formatC(signif(x, digits = n), digits = n, format = "fg", flag = "#")
}

# Null-coalescing operator (unexported)
`%||%` <- function(a, b) if (!is.null(a)) a else b
