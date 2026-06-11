# Mutate columns in a modelblueprint's datasets

Mutate columns in a modelblueprint's datasets

## Usage

``` r
# S3 method for class 'modelblueprint'
mutate(.data, ..., sets = c("train", "test", "holdout"))
```

## Arguments

- .data:

  A `modelblueprint`.

- ...:

  Expressions passed to
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html).

- sets:

  Which datasets to mutate. Default: all non-NULL.

## Value

A new `modelblueprint`.
