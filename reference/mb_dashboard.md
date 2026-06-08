# Launch an interactive dashboard for a modelblueprint

Opens a Shiny app that provides an interactive view of a fitted
`modelblueprint`. The app has four tabs:

## Usage

``` r
mb_dashboard(mb, ...)
```

## Arguments

- mb:

  A [`modelblueprint`](ModelBlueprint.md) object. Must have at least one
  of `@train`, `@test`, or `@holdout` set.

- ...:

  Currently unused. Reserved for future arguments.

## Value

A `shiny.appobj`. The app launches in the browser when the return value
is printed (the normal behaviour when called interactively). Returns
invisibly when assigned.

## Details

- **Summary** – model class, display name, target, exposure, dataset row
  counts, sum of target and exposure per split, the full variable list,
  and an overlaid density chart of the target vs model predictions.

- **Validation** – gain chart, predicted vs observed calibration, and
  grouped residuals. All three can be shown side-by-side across train,
  test, and holdout sets simultaneously, making overfitting immediately
  visible.

- **PDPs** – partial dependence plot for any variable in
  `@x_original_inputs`, with controls for bins, aggregation strategy,
  and sample size. Aggregated data can be downloaded as CSV.

- **One-ways** – exposure-weighted mean of the target across bins of any
  feature, with an optional model prediction overlay and split variable.
  Aggregated data can be downloaded as CSV.

All sidebar controls (bins, aggregation type, dataset) update plots
reactively. Errors in individual plots are caught and displayed inline
so a single failing chart never crashes the app.

## Required packages

`shiny`, `bslib`, and `plotly` must be installed. These are listed under
`Suggests` so they are not installed automatically with the package.
Install them with:

    install.packages(c("shiny", "bslib", "plotly"))

Install `shinycssloaders` for loading spinners on slow plots:

    install.packages("shinycssloaders")

## See also

[`pdp()`](pdp.md), [`one_way()`](one_way.md),
[`pred_vs_obs()`](pred_vs_obs.md), [`gain()`](gain.md),
[`residuals_grouped()`](residuals_grouped.md) for the underlying
functions used inside the dashboard.

## Examples

``` r
if (FALSE) { # \dontrun{
mb <- modelblueprint(
  model              = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train              = mtcars,
  y_name             = "vs",
  x_original_inputs  = c("wt", "hp"),
  model_display_name = "logistic_vs"
)

mb_dashboard(mb)
} # }
```
