# Load a modelblueprint from disk

Reconstructs a `modelblueprint` from a `.tar.gz` archive created by
[`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md).

`loadMB()` is deprecated; use `loadmb()` instead.

## Usage

``` r
loadmb(path)

loadMB(path)
```

## Arguments

- path:

  Path to the `.tar.gz` archive created by
  [`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md).

## Value

A fully reconstructed `modelblueprint` object.

## See also

[`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
