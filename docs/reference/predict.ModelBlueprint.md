# Generate predictions from a modelblueprint

Applies `pre_process_fun` -\> `feat_eng_fun` -\> model prediction -\>
`post_process_fun` to `newdata`.

## Usage

``` r
# S3 method for class 'modelblueprint'
predict(object, newdata, ...)
```

## Arguments

- object:

  A `modelblueprint`.

- newdata:

  A `data.frame` or `data.table`.

- ...:

  Unused.

## Value

A numeric vector of predictions.
