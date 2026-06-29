# Replace pipeline functions in a modelblueprint

Replace pipeline functions in a modelblueprint

## Usage

``` r
set_pre_process_fun(x, value, ...)

set_feat_eng_fun(x, value, ...)

set_post_process_fun(x, value, ...)
```

## Arguments

- x:

  A `modelblueprint`.

- value:

  A function with the expected signature for that pipeline stage.

- ...:

  Unused.

## Value

A new `modelblueprint`.

## See also

[`extract_pre_process_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_pipeline.md),
[`extract_feat_eng_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_pipeline.md),
[`extract_post_process_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_pipeline.md)
