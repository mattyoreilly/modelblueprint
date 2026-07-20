# Target distribution for a modelblueprint

Calls
[`distribution()`](https://mattyoreilly.github.io/modelblueprint/reference/distribution.md)
using the modelblueprint's target and exposure slots, showing the
exposure-weighted distribution of the target variable.

## Usage

``` r
# S3 method for class 'modelblueprint'
distribution(
  data,
  set = c("train", "test", "holdout"),
  split = NA_character_,
  bins = 35L,
  ...
)
```

## Arguments

- data:

  A `modelblueprint`.

- set:

  `[character(1)]` Which dataset to use: `"train"`, `"test"`, or
  `"holdout"`. Default `"train"`.

- split:

  `[character(1) | NA]` Optional split variable.

- bins:

  `[integer(1)]` Number of bins. Default `35L`.

- ...:

  Further arguments passed to
  [`distribution()`](https://mattyoreilly.github.io/modelblueprint/reference/distribution.md).

## Value

A plotly object or data.table depending on `ret`.
