# Place sorted-order bin labels back into the original row positions

[`bin_equal_exposure()`](https://mattyoreilly.github.io/modelblueprint/reference/bin_equal_exposure.md)
and
[`bin_equal_range()`](https://mattyoreilly.github.io/modelblueprint/reference/bin_equal_range.md)
operate on the sorted, non-NA values of a vector. Given the labels in
sorted order plus the precomputed ordering of the non-NA positions, this
writes each label back to its original row, leaving `NA` entries as
`NA_character_`. Callers decide how to label missing values (e.g. a
trailing "NA" category).

## Usage

``` r
remap_sorted_bins(binned_sorted, ord, n)
```

## Arguments

- binned_sorted:

  A factor/character vector of labels, one per non-NA value in ascending
  order.

- ord:

  Integer positions of the non-NA values, ordered ascending by value
  (i.e. `which(!is.na(x))` reordered by `order(x[...])`).

- n:

  `[integer(1)]` Length of the original vector.

## Value

A character vector of length `n`.
