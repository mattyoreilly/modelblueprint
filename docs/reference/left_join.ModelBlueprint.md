# Left-join into a modelblueprint's datasets

Left-join into a modelblueprint's datasets

## Usage

``` r
# S3 method for class 'modelblueprint'
left_join(x, y, by = NULL, ..., sets = c("train", "test", "holdout"))
```

## Arguments

- x:

  A `modelblueprint`.

- y:

  A `data.frame` to join.

- by:

  Join keys.

- ...:

  Passed to
  [`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html).

- sets:

  Which datasets to join. Default: all non-NULL.

## Value

A new `modelblueprint`.
