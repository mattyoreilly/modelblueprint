# Create a one-way analysis plot

Bins a feature variable, computes exposure-weighted means of one or more
observed variables per bin, and returns a dual-axis plotly chart (bars =
exposure, lines = weighted means). Optionally splits by a second
variable.

## Usage

``` r
one_way(data, ...)

# Default S3 method
one_way(
  data,
  var,
  obs = "target",
  exposure = "exposure",
  split = NA_character_,
  bins = 35L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
)
```

## Arguments

- data:

  A `data.frame` or `data.table`.

- ...:

  Arguments passed to methods.

- var:

  Column to plot on the x-axis. Bare name or string.

- obs:

  One or more columns to summarise on the y-axis (right axis). Bare
  name, `c(a, b)`, or character vector. Default `"target"`.

- exposure:

  Column of exposure weights. If the column does not exist in `data`,
  every row is given weight 1. Bare name or string. Default
  `"exposure"`.

- split:

  Optional column to split lines by. Bare name, string, or `NA` / `NULL`
  for no split. Default `NA`.

- bins:

  `[integer(1)]` Number of equal-exposure bins for numeric variables
  with more than `bins` unique values. Default 35.

- type_agg:

  `[character(1)]` Binning strategy for numeric variables:
  `"equal_exposure"` (default) or `"equal_range"`.

- ret:

  `[character(1)]` `"plot"` (default) returns a plotly object; `"data"`
  returns the aggregated data.table.

## Value

A plotly object, or a data.table when `ret = "data"`, or `NULL` with a
warning if the plot cannot be produced.

## Details

Column name arguments (`var`, `obs`, `exposure`, `split`) accept both
bare (unquoted) names and strings, so `one_way(df, wt, mpg)` and
`one_way(df, "wt", "mpg")` are equivalent.

## Examples

``` r
if (FALSE) { # \dontrun{
# bare names
one_way(mtcars, wt, mpg, bins = 10)
one_way(mtcars, cyl, c(mpg, hp), split = am)

# strings (equivalent)
one_way(mtcars, var = "wt", obs = "mpg", bins = 10)
one_way(mtcars, var = "cyl", obs = c("mpg", "hp"), split = "am")
} # }
```
