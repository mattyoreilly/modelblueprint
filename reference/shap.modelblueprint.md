# SHAP plots for a modelblueprint

Calls
[`shap()`](https://mattyoreilly.github.io/modelblueprint/reference/shap.md)
using the modelblueprint's model, data, and pipeline slots.

## Usage

``` r
# S3 method for class 'modelblueprint'
shap(
  data,
  vars = NA,
  set = c("train", "test", "holdout"),
  type = c("importance", "dependence"),
  nsim = 50L,
  sample_size = 500L,
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
)
```

## Arguments

- data:

  A `modelblueprint`.

- vars:

  `[character]` Features to compute SHAP for. Defaults to
  `data@x_original_inputs` when `NA`.

- set:

  `[character(1)]` Which dataset to use: `"train"` (default), `"test"`,
  or `"holdout"`.

- type:

  `[character(1)]` `"importance"` (default) or `"dependence"`. See
  [`shap()`](https://mattyoreilly.github.io/modelblueprint/reference/shap.md)
  for details.

- nsim:

  `[integer(1)]` Monte Carlo permutations per row. Default `50L`.

- sample_size:

  `[integer(1)]` Rows sampled for SHAP computation. Default `500L`.

- bins:

  `[integer(1)]` Number of bins for the dependence plot x-axis. Default
  `10L`.

- type_agg:

  `[character(1)]` Binning strategy: `"equal_exposure"` (default) or
  `"equal_range"`.

- ret:

  `[character(1)]` `"plot"` (default) or `"data"`.

- ...:

  Further arguments passed to
  [`shap()`](https://mattyoreilly.github.io/modelblueprint/reference/shap.md).

## Value

A plotly object, a named list of plotly objects, or a data.table
depending on `type` and `ret`.
