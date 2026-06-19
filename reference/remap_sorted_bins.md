# Map bin labels computed over sorted, non-NA values back to original row order

[`bin_equal_exposure()`](https://mattyoreilly.github.io/modelblueprint/reference/bin_equal_exposure.md)
and
[`bin_equal_range()`](https://mattyoreilly.github.io/modelblueprint/reference/bin_equal_range.md)
operate on the sorted, non-NA values of a vector. This helper places the
resulting labels back in the original positions of `x`, leaving `NA`
entries as `NA_character_`. Callers decide how to label missing values
(e.g. a trailing "NA" category).

## Usage

``` r
remap_sorted_bins(x, binned_sorted)
```

## Arguments

- x:

  The original (unsorted, possibly NA-containing) vector.

- binned_sorted:

  A factor/character vector of labels, one per element of
  `sort(x[!is.na(x)])`, in sorted order.

## Value

A character vector the same length as `x`.
