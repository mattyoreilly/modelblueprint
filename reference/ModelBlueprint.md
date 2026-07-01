# modelblueprint: a model-agnostic container for ML model lifecycles

modelblueprint: a model-agnostic container for ML model lifecycles

## Arguments

- model:

  A fitted model object. Any class implementing
  [`predict()`](https://rdrr.io/r/stats/predict.html).

- train, test, holdout:

  Datasets as `data.frame`. Default `NULL`.

- pre_process_fun:

  `function(df) -> df`. Pre-processing pipeline.

- feat_eng_fun:

  `function(df) -> df`. Feature engineering pipeline.

- post_process_fun:

  `function(preds, df_raw) -> numeric`. Post-processing.

- x_original_inputs:

  `[character]` Original input feature names.

- x_names:

  `[character]` Engineered feature names.

- y_name:

  `[character(1)]` Target variable name.

- yhat_name:

  `[character(1)]` Prediction column name.

- expo_name:

  `[character(1)]` Exposure column name.

- expo_val:

  `[numeric(1)]` Reference exposure value.

- expo_0_rep:

  `[numeric(1)]` Replacement for zero-exposure rows.

- offset_name:

  `[character(1)]` Offset variable name.

- offset_value:

  `[numeric(1)]` Offset value.

- model_display_name:

  `[character(1)]` Human-readable label.

- deploy_notes:

  `[character(1)]` Deployment notes.

## Construction

Create a blueprint by passing a fitted model plus, optionally, its data
splits and metadata:

    modelblueprint(
      model,
      train = NULL, test = NULL, holdout = NULL,
      pre_process_fun  = function(df) df,
      feat_eng_fun     = function(df) df,
      post_process_fun = function(preds, df_raw) preds,
      x_original_inputs = NA_character_, x_names = NA_character_,
      y_name = NA_character_, yhat_name = NA_character_,
      expo_name = "exposure", expo_val = 1, expo_0_rep = 0.1,
      offset_name = NA_character_, offset_value = NA_real_,
      model_display_name = NA_character_, deploy_notes = NA_character_
    )

Only `model` is required; every other property has a sensible default.
See the argument list and the example below for details.

## Examples

``` r
# Wrap a fitted model together with its training data and metadata.
mb <- modelblueprint(
  model              = lm(mpg ~ wt + hp, data = mtcars),
  train              = mtcars,
  y_name             = "mpg",
  x_original_inputs  = c("wt", "hp"),
  model_display_name = "lm_mpg"
)

mb                       # print method shows a structured summary
#> ============================================================ 
#> modelblueprint
#> ============================================================ 
#>   Model:        lm
#>   Display name: lm_mpg
#>   Target:       mpg
#>   Exposure:     exposure (val = 1)
#>   Features:     2 original / 0 engineered
#> ------------------------------------------------------------ 
#>   Train rows:   32
#>   Test rows:    <not set>
#>   Holdout rows: <not set>
#> ============================================================ 
predict(mb, head(mtcars))
#> [1] 23.57233 22.58348 25.27582 21.26502 18.32727 20.47382
```
