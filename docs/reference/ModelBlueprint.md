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

## Examples

``` r
if (FALSE) { # \dontrun{
mb <- modelblueprint(
  model  = lm(mpg ~ wt + hp, data = mtcars),
  train  = mtcars,
  y_name = "mpg"
)
predict(mb, mtcars)
} # }
```
