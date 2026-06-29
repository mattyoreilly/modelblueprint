# One-way analysis plots

## What is a one-way plot?

A one-way plot shows the exposure-weighted mean of one or more target
variables across bins of a single feature. It is the standard diagnostic
for understanding the univariate relationship between a feature and the
target in insurance and credit pricing.

The chart has a dual-axis layout:

- **Yellow bars (right axis)** — exposure per bin, showing data density
- **Lines (left axis)** — weighted mean of each target variable per bin

## Basic usage

``` r

# Default: 35 equal-exposure bins, target from y_name slot
one_way(mb, var = "driver_age")
```

You can also call
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
directly on a data frame:

``` r

one_way(mb@train, var = "driver_age", obs = "claim_freq", exposure = "exposure")
```

## Lift chart: overlaying model predictions

Pass `predictions = TRUE` to add the model’s in-sample predictions as a
second line. This creates a lift chart — the gap between the observed
and predicted lines reveals where the model over- or under-fits.

``` r

one_way(mb, var = "driver_age", predictions = TRUE)
```

The prediction column is named after `model_display_name` and appears in
the legend alongside the observed target.

## Multiple observed variables

Pass a character vector to `obs` to overlay several lines on the same
chart. Useful for comparing two competing models or a raw target against
a smoothed version.

``` r

one_way(mb, var = "vehicle_age", predictions = TRUE)
```

## Controlling bins

The `bins` argument controls how many bins the x-axis is divided into.

``` r

# Coarser view — 10 bins
one_way(mb, var = "driver_age", bins = 10L)
```

## Binning strategy

`type_agg` controls how bins are formed:

- **`"equal_exposure"`** (default) — quantile-based bins, each with
  roughly equal total exposure. Preferred for skewed distributions.
- **`"equal_range"`** — evenly-spaced bins across the feature range.
  Better for visualising the shape of the relationship at the tails.

``` r

one_way(mb, var = "vehicle_value", type_agg = "equal_range", bins = 10)
```

## Split variable

The `split` argument breaks each bin into groups, producing one line per
group. Useful for comparing behaviour across segments such as policy
type, region, or claim flag.

``` r

one_way(mb, var = "driver_age", split = "gender", bins = 10)
```

## Choosing the dataset

When calling from a `modelblueprint`, use `set` to choose which internal
dataset to plot. Comparing the same one-way on train vs test is a quick
check for overfitting.

``` r

one_way(mb, var = "driver_age", set = "train")
```

``` r

one_way(mb, var = "driver_age", set = "test")
```

## Returning the data

Pass `ret = "data"` to get the aggregated data.table instead of a plot.
Useful for custom visualisations or further analysis.

``` r

d <- one_way(mb, var = "driver_age", ret = "data")
head(d)
#>    driver_age    split claim_freq exposure
#>        <char>   <char>      <num>    <num>
#> 1:    [18,19] __none__  0.2363717    67.69
#> 2:    (19,21] __none__  0.1578781    63.34
#> 3:    (21,23] __none__  0.1249777    56.01
#> 4:    (23,25] __none__  0.1169249    68.42
#> 5:    (25,26] __none__  0.0307031    32.57
#> 6:    (26,28] __none__  0.1493348    73.66
```

The returned data.table has columns for the bin label, split group,
exposure, and one column per `obs` variable.

## Categorical variables

One-way plots handle categorical and low-cardinality integer variables
automatically — no binning is applied and each level appears as its own
bar.

``` r

one_way(mb, var = "area")
```

``` r

one_way(mb, var = "vehicle_type")
```
