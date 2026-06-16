# Apply binning to the `var` column of a data.table (in-place)

Returns the data.table unchanged if `var` is categorical or
low-cardinality.

## Usage

``` r
apply_binning(dt, bins, type_agg, time_unit = NA_character_)
```
