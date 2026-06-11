# Cumulative Gains Chart

Plots cumulative gains curves for one or more competing scores against a
perfect model baseline. The Gini coefficient for each score is shown in
the legend.

## Usage

``` r
gain(data, ...)

# S3 method for class 'modelblueprint'
gain(
  data,
  set = c("train", "test", "holdout"),
  title = NULL,
  ret = c("plot", "data", "gini"),
  ...,
  precomputed_preds = NULL
)
```

## Arguments

- data:

  A `modelblueprint` object.

- ...:

  Passed to the default method.

- set:

  Which dataset to use: `"train"`, `"test"`, or `"holdout"`.

- title:

  Chart title. Defaults to `model_display_name`.

- ret:

  `"plot"`, `"data"`, or `"gini"`. Default `"plot"`.

- precomputed_preds:

  `[numeric | NULL]` Optional vector of pre-computed predictions (one
  per row of the requested `set`). When supplied, the internal
  [`predict.modelblueprint()`](predict.modelblueprint.md) call is
  skipped. Use this in loops or dashboards where predictions have
  already been computed to avoid redundant scoring.

## Value

A plotly object, list of data.tables, or list of Gini values.

## Examples

``` r
if (FALSE) { # \dontrun{
mb <- modelblueprint(
  model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train  = mtcars,
  y_name = "vs",
  model_display_name = "logistic_vs"
)
gain(mb)
} # }
```
