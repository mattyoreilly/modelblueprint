# Extract a data split from a modelblueprint

Extract a data split from a modelblueprint

## Usage

``` r
extract_train(x, ...)

extract_test(x, ...)

extract_holdout(x, ...)
```

## Arguments

- x:

  A `modelblueprint`.

- ...:

  Unused.

## Value

A `data.frame` / `data.table`, or `NULL` if the split was not set.

## See also

[`set_train()`](https://mattyoreilly.github.io/modelblueprint/reference/set_splits.md),
[`set_test()`](https://mattyoreilly.github.io/modelblueprint/reference/set_splits.md),
[`set_holdout()`](https://mattyoreilly.github.io/modelblueprint/reference/set_splits.md)
