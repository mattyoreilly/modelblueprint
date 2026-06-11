# Predicted vs Observed Calibration Plot

Creates a Hosmer-style calibration chart showing average predicted
values against average observed values across bins of the prediction
space. A yellow exposure bar on the secondary axis shows the
distribution of data.

## Usage

``` r
pred_vs_obs(data, ...)

# Default S3 method
pred_vs_obs(
  data,
  pred = "predict",
  obs = "observed",
  exposure = "exposure",
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  title = "",
  ret = c("plot", "data"),
  ...
)

# S3 method for class 'modelblueprint'
pred_vs_obs(
  data,
  set = c("train", "test", "holdout"),
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  title = NULL,
  ret = c("plot", "data"),
  ...,
  precomputed_preds = NULL
)
```

## Arguments

- data:

  A `modelblueprint` object.

- ...:

  Passed to `pred_vs_obs.default()`.

- pred:

  `[character(1)]` Name of the predictions column.

- obs:

  `[character(1)]` Name of the observed target column.

- exposure:

  `[character(1)]` Name of the exposure column. Default `"exposure"`.

- bins:

  `[integer(1)]` Number of bins. Default `10L`.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

- title:

  `[character(1)]` Chart title. Defaults to `model_display_name`.

- ret:

  `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.

- set:

  `[character(1)]` Which dataset to use: `"train"`, `"test"`, or
  `"holdout"`. Default `"train"`.

- precomputed_preds:

  `[numeric | NULL]` Optional vector of pre-computed predictions (one
  per row of the requested `set`). When supplied, the internal
  [`predict.modelblueprint()`](predict.modelblueprint.md) call is
  skipped.

## Value

A plotly object or data.table depending on `ret`.

A plotly object or data.table depending on `ret`.

## Examples

``` r
if (FALSE) { # \dontrun{
mb <- modelblueprint(
  model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train  = mtcars,
  y_name = "vs",
  model_display_name = "logistic_vs"
)
pred_vs_obs(mb)
} # }
```
