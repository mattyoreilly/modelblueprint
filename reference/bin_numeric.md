# Bin a numeric vector and return labels aligned to original row order

Picks the binning strategy and applies it to the sorted, non-NA values,
then remaps the labels onto the original positions of `x`. The ordering
of the non-NA values is computed once (via a single
[`order()`](https://rdrr.io/r/base/order.html)) and reused for both the
sort and the remap, avoiding a redundant second pass over the data.
Returns both the aligned labels and the underlying
[`cut()`](https://rdrr.io/r/base/cut.html) factor so callers that need
the interval levels (e.g. to compute midpoints) can reuse them.

## Usage

``` r
bin_numeric(x, bins, type_agg)
```

## Arguments

- x:

  Numeric vector to bin.

- bins:

  `[integer(1)]` Number of bins.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

## Value

A list with `labels` (character, length of `x`, `NA` preserved) and
`cut` (the [`cut()`](https://rdrr.io/r/base/cut.html) factor over the
sorted non-NA values).
