# NSE wrapper for one_way

Allows bare (unquoted) column names to be passed instead of strings.
Delegates to [`one_way()`](one_way.md) after resolving names.

## Usage

``` r
one_way_nse(
  data,
  var,
  obs = target,
  exposure = exposure,
  split = NULL,
  bins = 35L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
)
```

## Arguments

- data:

  A data frame or data.table.

- var:

  Bare column name for the x-axis variable.

- obs:

  Bare column name(s) to summarise. Wrap multiple in
  [`c()`](https://rdrr.io/r/base/c.html), e.g. `c(mpg, hp)`. Default
  `target`.

- exposure:

  Bare column name for exposure weights. Default `exposure`.

- split:

  Bare column name to split lines by. Omit or pass `NULL` for no split.

- bins:

  `[integer(1)]` Number of bins. Default 35.

- type_agg:

  `[character(1)]` `"equal_exposure"` (default) or `"equal_range"`.

- ret:

  `[character(1)]` `"plot"` (default) or `"data"`.

- ...:

  Additional arguments passed to [`one_way()`](one_way.md).

## Value

See [`one_way()`](one_way.md).

## Examples

``` r
if (FALSE) { # \dontrun{
one_way_nse(mtcars, wt, mpg, bins = 10)
one_way_nse(mtcars, cyl, c(mpg, hp), split = am)
one_way_nse(loans_df, loan_amount, c(default_rate, loss_rate),
            exposure = n_accounts, split = risk_band)
} # }
```
