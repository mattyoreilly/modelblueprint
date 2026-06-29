# Extract the fitted model from a modelblueprint

Returns the raw model object stored in `@model` — the thing you would
pass directly to [`predict()`](https://rdrr.io/r/stats/predict.html),
[`coef()`](https://rdrr.io/r/stats/coef.html),
[`summary()`](https://rdrr.io/r/base/summary.html), etc.

## Usage

``` r
extract_fit(x, ...)
```

## Arguments

- x:

  A `modelblueprint`.

- ...:

  Unused; reserved for subclass methods.

## Value

The fitted model object.

## See also

[`set_model()`](https://mattyoreilly.github.io/modelblueprint/reference/set_model.md)
