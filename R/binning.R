# =============================================================================
# binning.R
# Shared binning primitives used by one_way(), pdp(), and shap().
#
# Centralising these here keeps the numeric-binning and sorted-index remapping
# logic in one place so the one_way and pdp code paths cannot drift apart.
# =============================================================================

# -----------------------------------------------------------------------------
# Column existence assertion
# -----------------------------------------------------------------------------

#' Abort if any of `cols` are missing from `data`
#' @keywords internal
assert_col_exists <- function(data, cols, arg_name) {
  missing_cols <- setdiff(cols, names(data))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "{arg_name} column(s) not found in {.arg data}: {.val {missing_cols}}"
    )
  }
}


# -----------------------------------------------------------------------------
# Numeric binning
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


# -----------------------------------------------------------------------------
# Sorted-index remapping
# -----------------------------------------------------------------------------

#' Map bin labels computed over sorted, non-NA values back to original row order
#'
#' `bin_equal_exposure()` and `bin_equal_range()` operate on the sorted, non-NA
#' values of a vector. This helper places the resulting labels back in the
#' original positions of `x`, leaving `NA` entries as `NA_character_`. Callers
#' decide how to label missing values (e.g. a trailing "NA" category).
#'
#' @param x             The original (unsorted, possibly NA-containing) vector.
#' @param binned_sorted A factor/character vector of labels, one per element of
#'                      `sort(x[!is.na(x)])`, in sorted order.
#' @return A character vector the same length as `x`.
#' @keywords internal
remap_sorted_bins <- function(x, binned_sorted) {
  labels <- rep(NA_character_, length(x))
  non_na_idx <- which(!is.na(x))
  sorted_non_na_idx <- non_na_idx[order(x[non_na_idx])]
  labels[sorted_non_na_idx] <- as.character(binned_sorted)
  labels
}

#' Bin a numeric vector and return labels aligned to original row order
#'
#' Thin wrapper that picks the binning strategy, applies it to the sorted,
#' non-NA values, and remaps the labels onto the original positions of `x` via
#' [remap_sorted_bins()]. Returns both the aligned labels and the underlying
#' `cut()` factor so callers that need the interval levels (e.g. to compute
#' midpoints) can reuse them.
#'
#' @param x        Numeric vector to bin.
#' @param bins     `[integer(1)]` Number of bins.
#' @param type_agg `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @return A list with `labels` (character, length of `x`, `NA` preserved) and
#'   `cut` (the `cut()` factor over the sorted non-NA values).
#' @keywords internal
bin_numeric <- function(x, bins, type_agg) {
  bin_fn <- if (type_agg == "equal_range") bin_equal_range else bin_equal_exposure
  x_sorted <- sort(x[!is.na(x)])
  cut_result <- suppressWarnings(bin_fn(x_sorted, bins))
  list(
    labels = remap_sorted_bins(x, cut_result),
    cut    = cut_result
  )
}
