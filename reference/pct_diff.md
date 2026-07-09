# Percentage difference vs a reference, formatted for hover text

Returns `""` wherever the percentage is not finite (reference of zero,
or either value missing) so tooltips never display "Inf%" or "NaN%".

## Usage

``` r
pct_diff(x, ref, digits = 1L)
```
