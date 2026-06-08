# Generate predictions from an mb_seq

Runs each layer in sequence, appending blueprint predictions and
aggregation outputs to the dataset as it goes.

## Usage

``` r
# S3 method for class 'mb_seq'
predict(object, newdata, return_all = FALSE, ...)
```

## Arguments

- object:

  An `mb_seq` object.

- newdata:

  A data frame or data.table.

- return_all:

  `[logical(1)]` If `FALSE` (default), returns the final layer's primary
  output as a numeric vector. If `TRUE`, returns a data frame containing
  all prediction columns added across all layers.

- ...:

  Unused.

## Value

A numeric vector (`return_all = FALSE`) or a data frame of all
prediction columns (`return_all = TRUE`).
