# Grouped Residuals vs Predicted Plot

Bins predictions by exposure, computes grouped residuals, and overlays a
loess trend line with a 95% confidence interval. Useful for diagnosing
systematic model bias across the prediction range.

## Usage

``` r
residuals_grouped(data, ...)

# Default S3 method
residuals_grouped(
  data,
  pred = "predict",
  obs = "observed",
  exposure = "exposure",
  exposure_per_bin = 10,
  residual_type = c("raw", "pearson"),
  title = "",
  ret = c("plot", "data"),
  ...
)

# S3 method for class 'modelblueprint'
residuals_grouped(
  data,
  set = c("train", "test", "holdout"),
  exposure_per_bin = 2500,
  residual_type = c("raw", "pearson"),
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

  Passed to `residuals_grouped.default()`.

- pred:

  `[character(1)]` Name of the predictions column.

- obs:

  `[character(1)]` Name of the observed target column.

- exposure:

  `[character(1)]` Name of the exposure column. Default `"exposure"`.

- exposure_per_bin:

  `[numeric(1)]` Target exposure per bin. Default `2500`. Automatically
  reduced if the dataset is too small for meaningful grouping.

- residual_type:

  `[character(1)]` `"raw"` or `"pearson"`.

- title:

  `[character(1)]` Chart title. Defaults to `model_display_name`.

- ret:

  `[character(1)]` `"plot"` or `"data"`.

- set:

  `[character(1)]` Dataset to use: `"train"`, `"test"`, or `"holdout"`.
  Default `"train"`.

- precomputed_preds:

  `[numeric | NULL]` Optional vector of pre-computed predictions (one
  per row of the requested `set`). When supplied, the internal
  [`predict.modelblueprint()`](https://mattyoreilly.github.io/modelblueprint/reference/predict.ModelBlueprint.md)
  call is skipped.

## Value

A plotly object or data.table depending on `ret`.

A plotly object or data.table depending on `ret`.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- data.frame(
  obs      = rbinom(500, 1, 0.3),
  pred     = runif(500, 0.1, 0.5),
  exposure = rep(1, 500)
)
residuals_grouped(df, pred = "pred", obs = "obs", exposure = "exposure")
} # }
if (FALSE) { # \dontrun{
mb <- modelblueprint(
  model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train  = mtcars,
  y_name = "vs",
  model_display_name = "logistic_vs"
)
residuals_grouped(mb)
} # }
```
