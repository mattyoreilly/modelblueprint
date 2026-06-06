# Partial dependence plot for any predict()-compatible model

For each bin of `var`, the function fixes that feature at the bin
midpoint (numeric) or bin label (categorical), runs
[`predict()`](https://rdrr.io/r/stats/predict.html) across a sample of
the full dataset, and averages the predictions. The result shows the
marginal effect of `var` on model output, stripped of all correlations
with other features.

## Usage

``` r
pdp(data, ...)

# Default S3 method
pdp(
  data,
  var,
  obs,
  model,
  exposure = "exposure",
  bins = 10L,
  sample_size = 10000L,
  type_agg = c("equal_exposure", "equal_range"),
  model_name = "model",
  ret = c("plot", "data"),
  pre_process_fun = function(df) df,
  feat_eng_fun = function(df) df,
  post_process_fun = function(preds, df_raw) preds,
  ...
)
```

## Arguments

- data:

  A `data.frame` or `data.table`.

- ...:

  Arguments passed to methods.

- var:

  `[character(1)]` Feature column to vary on the x-axis.

- obs:

  `[character(1)]` Observed target column name.

- model:

  A fitted model object. Standard R models (lm, glm, xgb, ranger,
  tidymodels workflows, etc.) and H2O models are supported
  automatically - no extra arguments needed.

- exposure:

  `[character(1)]` Exposure weight column. If absent, every row is given
  weight 1. Default `"exposure"`.

- bins:

  `[integer(1)]` Number of bins for numeric `var`. Default 10.

- sample_size:

  `[integer(1)]` Rows to sample for PDP computation. Reducing this
  speeds up prediction at the cost of accuracy. Default 10,000. The full
  dataset is always used for the one-way actuals.

- type_agg:

  `[character(1)]` Binning strategy: `"equal_exposure"` (default) or
  `"equal_range"`.

- model_name:

  `[character(1)]` Label shown in the plot legend. Default `"model"`.

- ret:

  `[character(1)]` `"plot"` (default) returns a plotly object; `"data"`
  returns the aggregated data.table.

## Value

A plotly object, or a data.table when `ret = "data"`, or `NULL` with a
warning when the variable cannot be plotted.

## Details

Alongside the PDP line the chart also shows:

- Observed mean per bin (actual target, exposure-weighted)

- Model average prediction per bin (in-sample, not PDP)

- Global average observed and predicted reference lines

- Yellow exposure bars (left axis) - identical style to
  [`one_way()`](https://matt-or.github.io/modelblueprint/reference/one_way.md)

## See also

[`one_way()`](https://matt-or.github.io/modelblueprint/reference/one_way.md)
for observed-only one-way analysis.

## Examples

``` r
if (FALSE) { # \dontrun{
m <- lm(mpg ~ wt + hp + cyl, data = mtcars)

# Basic usage
pdp(mtcars, var = "wt", obs = "mpg", model = m)

# GLM - predict() is dispatched automatically
g <- glm(vs ~ wt + hp, data = mtcars, family = binomial)
pdp(mtcars, var = "wt", obs = "vs", model = g)

# Return aggregated data instead of a plot
pdp(mtcars, var = "wt", obs = "mpg", model = m, ret = "data")
} # }
```
