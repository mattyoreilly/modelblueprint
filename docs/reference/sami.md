# SAMI Double Lift Chart

For each pair of competing predictions, bins the ratio of one prediction
to another and plots the observed mean alongside both model means per
bin. Useful for diagnosing where two models systematically disagree.

## Usage

``` r
sami(data, ...)

# Default S3 method
sami(
  data,
  obs,
  pred,
  bins = 50L,
  exposure = "exposure",
  type_agg = c("equal_exposure", "equal_range"),
  recalib = FALSE,
  ret = c("plot", "data"),
  ...
)

# S3 method for class 'list'
sami(
  data,
  set = c("train", "test", "holdout"),
  bins = 20L,
  type_agg = c("equal_exposure", "equal_range"),
  recalib = FALSE,
  pred_names = NA_character_,
  ret = c("plot", "data"),
  ...
)
```

## Arguments

- data:

  A list of `modelblueprint` objects. Must have length 2 or more. All
  blueprints must share the same `y_name`, `expo_name`, and training
  data structure.

- ...:

  Passed to the default method.

- obs:

  `[character(1)]` Name of the observed target column.

- pred:

  `[character]` Names of two or more competing prediction columns.

- bins:

  `[integer(1)]` Number of bins. Default `20L`.

- exposure:

  `[character(1)]` Name of the exposure column. Default `"exposure"`.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

- recalib:

  `[logical(1)]` Recalibrate predictions. Default `FALSE`.

- ret:

  `[character(1)]` `"plot"` or `"data"`.

- set:

  `[character(1)]` Which dataset to use from the first blueprint:
  `"train"`, `"test"`, or `"holdout"`. Default `"train"`.

- pred_names:

  `[character]` Optional vector of names for prediction columns. Length
  must match `length(data)`. When `NA`, names are derived from
  `model_display_name`.

## Value

A named list of plotly objects or a data.table depending on `ret`.

A named list of plotly objects or a data.table.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- data.frame(
  obs      = rnorm(500, 100),
  pred1    = rnorm(500, 100),
  pred2    = rnorm(500, 105),
  exposure = rep(1, 500)
)
sami(df, obs = "obs", pred = c("pred1", "pred2"), bins = 10)
} # }
if (FALSE) { # \dontrun{
mb1 <- modelblueprint(model = lm(mpg ~ wt, mtcars), train = mtcars,
                       y_name = "mpg", model_display_name = "lm_wt")
mb2 <- modelblueprint(model = lm(mpg ~ hp, mtcars), train = mtcars,
                       y_name = "mpg", model_display_name = "lm_hp")
sami(list(mb1, mb2), set = "train", bins = 10)
} # }
```
