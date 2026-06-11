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

library(modelblueprint)

mb <- mb_glm_binomial()

# Default: 35 equal-exposure bins, target from y_name slot
one_way(mb, var = "wt")
```

You can also call
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
directly on a data frame:

``` r

one_way(mtcars, var = "wt", obs = "vs", exposure = "exposure")
```

## Lift chart: overlaying model predictions

Pass `predictions = TRUE` to add the model’s in-sample predictions as a
second line. This creates a lift chart — the gap between the observed
and predicted lines reveals where the model over- or under-fits.

``` r

one_way(mb, var = "wt", predictions = TRUE)
```

The prediction column is named after `model_display_name` and appears in
the legend alongside the observed target.

## Multiple observed variables

Pass a character vector to `obs` to overlay several lines on the same
chart. Useful for comparing two competing models or a raw target against
a smoothed version.

``` r

# Compare two model predictions directly
one_way(
  mtcars,
  var      = "wt",
  obs      = c("vs", "am"),   # two lines
  exposure = "exposure"
)
```

## Controlling bins

The `bins` argument controls how many bins the x-axis is divided into.

``` r

# Coarser view — 10 bins
one_way(mb, var = "wt", bins = 10L)

# Finer view — 50 bins
one_way(mb, var = "wt", bins = 50L)
```

## Binning strategy

`type_agg` controls how bins are formed:

- **`"equal_exposure"`** (default) — quantile-based bins, each with
  roughly equal total exposure. Preferred for skewed distributions.
- **`"equal_range"`** — evenly-spaced bins across the feature range.
  Better for visualising the shape of the relationship at the tails.

``` r

one_way(mb, var = "wt", type_agg = "equal_range", bins = 5)
```

## Split variable

The `split` argument breaks each bin into groups, producing one line per
group. Useful for comparing behaviour across segments such as policy
type, region, or claim flag.

``` r

one_way(mb, var = "mpg", split = "am", bins = 5)   # split by transmission type
```

## Choosing the dataset

When calling from a `modelblueprint`, use `set` to choose which internal
dataset to plot. Comparing the same one-way on train vs test is a quick
check for overfitting.

``` r

one_way(mb, var = "wt", set = "train")
one_way(mb, var = "wt", set = "test")
```

## Returning the data

Pass `ret = "data"` to get the aggregated data.table instead of a plot.
Useful for custom visualisations or further analysis.

``` r

d <- one_way(mb, var = "wt", ret = "data")
head(d)
```

The returned data.table has columns for the bin label, split group,
exposure, and one column per `obs` variable.

## Categorical variables

One-way plots handle categorical and low-cardinality integer variables
automatically — no binning is applied and each level appears as its own
bar. Levels with more than 2,000 unique values trigger a warning and
return `NULL`.

``` r

mtcars$cyl_f <- as.character(mtcars$cyl)
one_way(mtcars, var = "cyl_f", obs = "vs", exposure = "exposure")
```
