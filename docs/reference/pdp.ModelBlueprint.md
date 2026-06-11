# Partial dependence plot for a modelblueprint

Calls
[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
using the modelblueprint's model, target, exposure, and data slots.

## Usage

``` r
# S3 method for class 'modelblueprint'
pdp(
  data,
  var = NA,
  set = c("train", "test", "holdout"),
  bins = 10L,
  sample_size = 10000L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
)
```

## Arguments

- data:

  A `modelblueprint`.

- var:

  `[character(1)]` Feature to compute the PDP for.

- set:

  `[character(1)]` Dataset to use: `"train"`, `"test"`, or `"holdout"`.
  Default `"train"`.

- bins:

  `[integer(1)]` Number of bins. Default `10L`.

- sample_size:

  `[integer(1)]` Rows to sample. Default `10000L`.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

- ret:

  `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.

- ...:

  Further arguments passed to
  [`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md).

## Value

A plotly object or data.table depending on `ret`.
