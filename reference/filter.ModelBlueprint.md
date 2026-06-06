# Filter rows in a modelblueprint's datasets

Filter rows in a modelblueprint's datasets

## Usage

``` r
# S3 method for class 'modelblueprint'
filter(.data, ..., sets = c("train", "test", "holdout"))
```

## Arguments

- .data:

  A `modelblueprint`.

- ...:

  Filter expressions passed to
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html).

- sets:

  Which datasets to filter. Default: all non-NULL.

## Value

A new `modelblueprint`.
