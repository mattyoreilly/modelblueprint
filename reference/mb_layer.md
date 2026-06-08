# Construct a single layer for use in an [`mb_seq()`](mb_seq.md)

A layer holds one or more `modelblueprint` objects that run in parallel.
Each blueprint appends its prediction (under `@yhat_name`) to the
dataset. `aggregate_fn` then receives the enriched dataset and can add
further derived columns. `yhat_name` declares the layer's primary output
column – this is what
[`predict()`](https://rdrr.io/r/stats/predict.html) returns when
`return_all = FALSE`, and what downstream layers can reference as a
feature.

## Usage

``` r
mb_layer(blueprints, aggregate_fn = NULL, yhat_name = NULL)
```

## Arguments

- blueprints:

  A list of `modelblueprint` objects. Every blueprint must have
  `@yhat_name` set.

- aggregate_fn:

  `function(df) -> df`. Receives the dataset after all blueprint
  predictions have been appended and returns it, optionally with
  additional columns. Defaults to the identity function when
  `blueprints` has one element; required when there are multiple
  blueprints.

- yhat_name:

  `[character(1)]` The primary output column of this layer. When
  `aggregate_fn` is `NULL`, defaults to the single blueprint's
  `@yhat_name`. When `aggregate_fn` is provided, set this to the column
  `aggregate_fn` adds that represents the layer's combined prediction.

## Value

An `mb_layer` object.

## See also

[`mb_seq()`](mb_seq.md) to combine layers into a pipeline.

## Examples

``` r
if (FALSE) { # \dontrun{
# Single model -- aggregate_fn and yhat_name default to the blueprint's yhat_name
l1 <- mb_layer(list(mb_freq))

# Two models combined as a product
l2 <- mb_layer(
  blueprints = list(mb_freq, mb_sev),
  yhat_name  = "pred_pure",
  aggregate_fn     = function(df) {
    df[["pred_pure"]] <- df[["pred_freq"]] * df[["pred_sev"]]
    df
  }
)
} # }
```
