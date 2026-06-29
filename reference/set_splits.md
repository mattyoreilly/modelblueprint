# Replace a data split in a modelblueprint

Replace a data split in a modelblueprint

## Usage

``` r
set_train(x, value, ...)

set_test(x, value, ...)

set_holdout(x, value, ...)
```

## Arguments

- x:

  A `modelblueprint`.

- value:

  A `data.frame` or `data.table`.

- ...:

  Unused.

## Value

A new `modelblueprint`.

## See also

[`extract_train()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_splits.md),
[`extract_test()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_splits.md),
[`extract_holdout()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_splits.md)
