# Set scalar metadata on a modelblueprint

Set scalar metadata on a modelblueprint

## Usage

``` r
set_target(x, value, ...)

set_yhat_name(x, value, ...)

set_exposure_name(x, value, ...)

set_exposure_value(x, value, ...)

set_exposure_zero_rep(x, value, ...)

set_offset_name(x, value, ...)

set_offset_value(x, value, ...)

set_display_name(x, value, ...)

set_deploy_notes(x, value, ...)
```

## Arguments

- x:

  A `modelblueprint`.

- value:

  A single string (or numeric for `set_exposure_value` /
  `set_exposure_zero_rep` / `set_offset_value`).

- ...:

  Unused.

## Value

A new `modelblueprint`.
