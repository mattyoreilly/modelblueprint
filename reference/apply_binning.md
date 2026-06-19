# Bin the named column of a data.table in place

Replaces `dt[[col]]` with character bin labels. Returns the data.table
unchanged when the column is categorical or low-cardinality. Handles
Date/datetime columns when `time_unit` is supplied.

## Usage

``` r
apply_binning(dt, col, bins, type_agg, time_unit = NA_character_)
```

## Arguments

- dt:

  A data.table.

- col:

  `[character(1)]` Name of the column to bin in place.

- bins:

  `[integer(1)]` Number of bins.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

- time_unit:

  `[character(1)]` Optional date bin width for Date/POSIXct columns
  (passed to
  [`base::cut.POSIXt()`](https://rdrr.io/r/base/cut.POSIXt.html)).
