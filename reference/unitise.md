# unitise a numeric variable to the range 0 to 1

Caps a variable at `min_val` and `max_val` then scales it between 0
and 1. Returns a modified copy — the caller's data is never mutated.

## Usage

``` r
unitise(data, var, min_val, max_val)
```

## Arguments

- data:

  A `data.frame` or `data.table`.

- var:

  `[character(1)]` Name of the column to unitise.

- min_val:

  `[numeric(1)]` Lower cap. Values below this are set to 0.

- max_val:

  `[numeric(1)]` Upper cap. Values above this are set to 1.

## Value

A copy of `data` with `var` scaled 0 to 1.
