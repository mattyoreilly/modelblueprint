# One-way analysis for a modelblueprint

Calls
[`one_way()`](https://matt-or.github.io/modelblueprint/reference/one_way.md)
using the modelblueprint's target, exposure, and data slots. Optionally
overlays the model's in-sample predictions to produce a lift chart (pass
`predictions = TRUE`).

## Usage

``` r
# S3 method for class 'modelblueprint'
one_way(
  data,
  var,
  set = c("train", "test", "holdout"),
  predictions = FALSE,
  split = NA_character_,
  bins = 35L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
)
```

## Arguments

- data:

  A `modelblueprint`.

- var:

  `[character(1)]` Feature to plot on the x-axis.

- set:

  `[character(1)]` Which dataset to use: `"train"`, `"test"`, or
  `"holdout"`. Default `"train"`.

- predictions:

  `[logical(1)]` If `TRUE`, adds in-sample model predictions as a second
  line (lift chart mode). Default `FALSE`.

- split:

  `[character(1) | NA]` Optional split variable.

- bins:

  `[integer(1)]` Number of bins. Default `35L`.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

- ret:

  `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.

- ...:

  Further arguments passed to
  [`one_way()`](https://matt-or.github.io/modelblueprint/reference/one_way.md).

## Value

A plotly object or data.table depending on `ret`.
