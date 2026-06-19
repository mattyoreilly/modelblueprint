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

#' Place sorted-order bin labels back into the original row positions
#'
#' `bin_equal_exposure()` and `bin_equal_range()` operate on the sorted, non-NA
#' values of a vector. Given the labels in sorted order plus the precomputed
#' ordering of the non-NA positions, this writes each label back to its original
#' row, leaving `NA` entries as `NA_character_`. Callers decide how to label
#' missing values (e.g. a trailing "NA" category).
#'
#' @param binned_sorted A factor/character vector of labels, one per non-NA
#'                      value in ascending order.
#' @param ord           Integer positions of the non-NA values, ordered
#'                      ascending by value (i.e. `which(!is.na(x))` reordered by
#'                      `order(x[...])`).
#' @param n             `[integer(1)]` Length of the original vector.
#' @return A character vector of length `n`.
#' @keywords internal
remap_sorted_bins <- function(binned_sorted, ord, n) {
  labels <- rep(NA_character_, n)
  labels[ord] <- as.character(binned_sorted)
  labels
}

#' Bin a numeric vector and return labels aligned to original row order
#'
#' Picks the binning strategy and applies it to the sorted, non-NA values, then
#' remaps the labels onto the original positions of `x`. The ordering of the
#' non-NA values is computed once (via a single `order()`) and reused for both
#' the sort and the remap, avoiding a redundant second pass over the data.
#' Returns both the aligned labels and the underlying `cut()` factor so callers
#' that need the interval levels (e.g. to compute midpoints) can reuse them.
#'
#' @param x        Numeric vector to bin.
#' @param bins     `[integer(1)]` Number of bins.
#' @param type_agg `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @return A list with `labels` (character, length of `x`, `NA` preserved) and
#'   `cut` (the `cut()` factor over the sorted non-NA values).
#' @keywords internal
bin_numeric <- function(x, bins, type_agg) {
  bin_fn <- if (type_agg == "equal_range") bin_equal_range else bin_equal_exposure
  non_na_idx <- which(!is.na(x))
  ord <- non_na_idx[order(x[non_na_idx])] # non-NA positions, ascending by value
  cut_result <- suppressWarnings(bin_fn(x[ord], bins))
  list(
    labels = remap_sorted_bins(cut_result, ord, length(x)),
    cut    = cut_result
  )
}
