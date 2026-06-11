# A sequential pipeline of model layers

`mb_seq` chains one or more `mb_layer` objects together. Each layer runs
after the previous one, receiving a dataset enriched with all
predictions produced so far. This allows later layers to use earlier
predictions as input features.

## Usage

``` r
mb_seq(
  ...,
  train = NULL,
  test = NULL,
  holdout = NULL,
  y_name = NA_character_,
  expo_name = NA_character_,
  model_display_name = NA_character_
)
```

## Arguments

- ...:

  One or more `mb_layer` objects, in execution order.

- train, test, holdout:

  Data frames for model development and evaluation.

- y_name:

  `[character(1)]` Final target variable name. Used by diagnostic
  functions.

- expo_name:

  `[character(1)]` Exposure column name. Default `NA`.

- model_display_name:

  `[character(1)]` Human-readable label.

## Value

An `mb_seq` object.

## Details

At construction time, `mb_seq` validates that every blueprint's required
columns (`@x_original_inputs`, `@expo_name`, `@offset_name`) are present
in the supplied data at the point that blueprint would run – accounting
for the fact that earlier layers add new columns.

## See also

[`mb_layer()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_layer.md)
to construct individual layers,
[`predict.mb_seq()`](https://mattyoreilly.github.io/modelblueprint/reference/predict.mb_seq.md)
for generating predictions.

## Examples

``` r
if (FALSE) { # \dontrun{
# Pure premium: frequency * severity
seq_ps <- mb_seq(
  mb_layer(
    blueprints = list(mb_freq, mb_sev),
    yhat_name  = "pred_pure",
    aggregate_fn     = function(df) {
      df[["pred_pure"]] <- df[["pred_freq"]] * df[["pred_sev"]]
      df
    }
  ),
  train              = df_train,
  y_name             = "burn_cost",
  expo_name          = "earned_premium",
  model_display_name = "pure_premium"
)

# Expected loss: PD x EAD x LGD
seq_el <- mb_seq(
  mb_layer(
    blueprints = list(mb_pd, mb_ead, mb_lgd),
    yhat_name  = "pred_el",
    aggregate_fn     = function(df) {
      df[["pred_el"]] <- df[["pred_pd"]] * df[["pred_ead"]] * df[["pred_lgd"]]
      df
    }
  ),
  train  = df_train,
  y_name = "actual_loss"
)

# Sequential: GLM output feeds XGBoost as a feature
seq_chain <- mb_seq(
  mb_layer(list(mb_glm)),
  mb_layer(list(mb_xgb)),
  train  = df_train,
  y_name = "target"
)
} # }
```
