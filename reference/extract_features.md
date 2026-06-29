# Extract feature name vectors from a modelblueprint

`extract_original_inputs()` returns `@x_original_inputs` — the column
names present in the raw data before any feature engineering.
`extract_feature_names()` returns `@x_names` — the names after feature
engineering (i.e. what the model actually sees).

## Usage

``` r
extract_original_inputs(x, ...)

extract_feature_names(x, ...)
```

## Arguments

- x:

  A `modelblueprint`.

- ...:

  Unused.

## Value

A character vector, with `NA_character_` values removed.

## See also

[`set_original_inputs()`](https://mattyoreilly.github.io/modelblueprint/reference/set_features.md),
[`set_feature_names()`](https://mattyoreilly.github.io/modelblueprint/reference/set_features.md)
