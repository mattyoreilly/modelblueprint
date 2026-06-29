# Swap the fitted model inside a modelblueprint

Returns a new `modelblueprint` with `@model` replaced by `value`. Use
this after retraining to keep all pipeline functions and metadata
intact.

## Usage

``` r
set_model(x, value, ...)
```

## Arguments

- x:

  A `modelblueprint`.

- value:

  A fitted model object.

- ...:

  Unused.

## Value

A new `modelblueprint`.

## See also

[`extract_fit()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_fit.md)
