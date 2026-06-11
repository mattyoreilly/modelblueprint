# Interactive model dashboard

You have a fitted model. You want to know whether it overfits, whether
it is well-calibrated, and how each feature drives predictions — without
writing twenty lines of plotting code for every diagnostic.
[`mb_dashboard()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md)
gives you all of that in a single function call.

## Required packages

The dashboard depends on three packages listed under `Suggests`. Install
them once if you have not already:

``` r

install.packages(c("shiny", "bslib", "plotly"))

# Optional --- adds loading spinners on slow plots
install.packages("shinycssloaders")
```

## Launching the dashboard

Build a `modelblueprint` with at least one data split and call
[`mb_dashboard()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md).
The app opens in your browser; the R session stays blocked until you
close the window.

``` r

mb <- modelblueprint(
  model              = glm(vs ~ wt + hp + am, data = mtcars, family = binomial),
  train              = mtcars[1:24, ],
  test               = mtcars[25:32, ],
  y_name             = "vs",
  x_original_inputs  = c("wt", "hp", "am"),
  model_display_name = "logistic_vs"
)
```

``` r

mb_dashboard(mb)
```

Any model that implements
[`predict()`](https://rdrr.io/r/stats/predict.html) works — `lm`, `glm`,
`rpart`, `randomForest`, `xgboost`, and H2O models are all supported out
of the box. The built-in example constructors in
[`?mb_examples`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
provide ready-made objects for quick experimentation:

``` r

mb_dashboard(mb_glm_binomial())
mb_dashboard(mb_rf_regression())
```

------------------------------------------------------------------------

## The Summary tab

![The Summary tab: model card, dataset card, variable list, and
target/prediction density overlay.](figures/dashboard-summary.png)

The Summary tab: model card, dataset card, variable list, and
target/prediction density overlay.

The first tab shows a model card and dataset card side by side, followed
by a variable list and a target-vs-predicted density overlay.

**Model card** — class, display name, target, exposure column, and any
deploy notes stored on the object.

**Datasets card** — row count, sum of the target, and sum of exposure
for each split (train / test / holdout). Missing splits show `—`.

**Variables** — the original input features (`@x_original_inputs`) and
any engineered features (`@x_names`) stored on the blueprint.

**Distribution plot** — overlaid density histograms of the observed
target and the model’s in-sample predictions. A well-calibrated model
should have similar shapes. The dataset selector and bin slider in the
card header update the chart reactively.

------------------------------------------------------------------------

## The Validation tab

![Validation tab with all three splits visible. Comparing Gini
coefficients across train and test makes overfitting immediately
visible.](figures/dashboard-validation-3set.png)

Validation tab with all three splits visible. Comparing Gini
coefficients across train and test makes overfitting immediately
visible.

The Validation tab shows three diagnostic charts for each selected
dataset split, arranged in side-by-side columns. Use the **Sets to
show** checkbox group in the sidebar to control which splits are
displayed; the layout reflows and all charts resize automatically.

![With only train selected the column expands to full
width.](figures/dashboard-validation-1set.png)

With only train selected the column expands to full width.

### Gain chart

Ranks predictions from highest to lowest, then plots the cumulative
share of the target captured as a fraction of the portfolio. A model
with no discriminatory power produces a straight diagonal (random). The
Gini coefficient — the area between the model curve and the diagonal —
is shown in the legend. Comparing Gini across train and test in a single
view makes overfitting immediately visible.

### Predicted vs Observed

Bins the data by predicted value (equal-exposure by default), then plots
the exposure-weighted mean observed rate against the exposure-weighted
mean predicted rate per bin. Perfect calibration is a diagonal.
Systematic curvature indicates a transformation or offset problem. The
**Bins** and **Aggregation** sidebar controls update all three sets
simultaneously.

### Grouped residuals

Sorts rows by predicted value, groups them into bands of fixed exposure,
and plots the mean residual per band with a loess trend line. A flat
trend through zero means the model has no systematic bias across the
prediction range.

### Expanding a chart

Each inner chart card has a small expand icon in the top-right corner.
Clicking it fills the viewport with that chart — useful for
presentations or for examining dense gain curves in detail.

------------------------------------------------------------------------

## The PDPs tab

![The PDPs tab showing the marginal effect of wt on predicted vs. the
observed mean.](figures/dashboard-pdp.png)

The PDPs tab showing the marginal effect of wt on predicted vs. the
observed mean.

A partial dependence plot (PDP) shows the marginal effect of one feature
on the model’s output, averaged over the joint distribution of all other
features. The feature selector, bin count, aggregation strategy, and
sample size are all reactive controls.

``` r

# The same chart outside the dashboard:
pdp(mb, var = "wt")
```

**Sample size** controls how many rows are used for the PDP computation.
Larger values are more accurate; smaller values are faster. For large or
slow models (H2O, XGBoost on millions of rows), reducing this to
2,000–5,000 is often sufficient and keeps the chart interactive. Inputs
are debounced at 800 ms so adjusting a slider does not fire a prediction
call on every tick.

The **Download data** button exports the aggregated PDP values as a CSV.

------------------------------------------------------------------------

## The One-ways tab

![One-way with predictions overlay: the solid line is the observed mean,
the dashed line is the model's mean prediction per
bin.](figures/dashboard-oneway.png)

One-way with predictions overlay: the solid line is the observed mean,
the dashed line is the model’s mean prediction per bin.

One-way plots show the exposure-weighted mean of the target across bins
of a feature, with no model involvement. They answer: *how does the raw
observed rate change as this feature increases?*

Enabling **Overlay predictions** adds a second line for the model’s
exposure-weighted mean prediction per bin, turning the chart into a lift
chart. Gaps between the two lines reveal where the model and the data
disagree.

![Split by am: the effect of wt on vs differs between automatic (0) and
manual (1) transmissions.](figures/dashboard-oneway-split.png)

Split by am: the effect of wt on vs differs between automatic (0) and
manual (1) transmissions.

The **Split by** dropdown segments each bin by a categorical feature,
producing one line per level. This is useful for checking whether a
feature’s effect differs across subgroups.

``` r

# The same chart outside the dashboard:
one_way(mb, var = "wt", predictions = TRUE)
```

------------------------------------------------------------------------

## Large models and the prediction cache

For H2O, XGBoost, or any model where a single
[`predict()`](https://rdrr.io/r/stats/predict.html) call on the full
dataset takes several seconds, the dashboard would be unusably slow if
each chart computed predictions independently. The gain,
predicted-vs-observed, residuals, distribution, and one-way overlay
charts would each trigger a separate full-dataset scoring pass.

[`mb_dashboard()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md)
avoids this with a per-set prediction cache: the first chart that needs
predictions for a given split computes them and stores the result; every
subsequent chart in the session reads from that cache. A notification
appears while the computation runs so the UI does not appear frozen.

``` r

# The cache is transparent --- launch the dashboard as normal.
# For a large H2O model:
mb_dashboard(mb_h2o_glm_large(n = 50000L))
```

The same `precomputed_preds` argument is available on every individual
diagnostic function, so you can take advantage of the cache when working
outside the dashboard too:

``` r

preds <- predict(mb, mtcars)

gain(mb,               set = "train", precomputed_preds = preds)
pred_vs_obs(mb,        set = "train", precomputed_preds = preds)
residuals_grouped(mb,  set = "train", precomputed_preds = preds)
one_way(mb, var = "wt", predictions = TRUE, precomputed_preds = preds)
```

------------------------------------------------------------------------

## Deploying the dashboard

[`mb_dashboard()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md)
returns a `shiny.appobj`. To deploy it, save the blueprint to disk with
[`saveMB()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
and create a self-contained `app.R` that loads it:

``` r

saveMB(mb, path = "my_app/", filename = "model")
```

``` r

# my_app/app.R
library(modelblueprint)
mb <- loadMB("model.tar.gz")
mb_dashboard(mb)
```

The `my_app/` folder can then be published with:

| Target | Command |
|----|----|
| shinyapps.io | `rsconnect::deployApp("my_app/")` |
| Posit Connect | `rsconnect::deployApp("my_app/", server = "your-connect-server")` |
| Docker / VPS | `rocker/shiny` base image + `COPY my_app/ /srv/shiny-server/mb/` |

Since the package is not yet on CRAN, pin dependencies with `renv`
before deploying so the remote server installs the correct version:

``` r

renv::init()       # in my_app/
renv::snapshot()   # captures modelblueprint and all dependencies
```

> **H2O models** require a JVM on the target server. `rocker/shiny` with
> `RUN apt-get install -y default-jdk` added to the Dockerfile is the
> most reliable path; H2O on shinyapps.io is not recommended.

------------------------------------------------------------------------

## See also

- [`?mb_dashboard`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md)
  — full function reference
- [`vignette("getting-started")`](https://mattyoreilly.github.io/modelblueprint/articles/getting-started.md)
  — building your first `modelblueprint`
- [`vignette("model-diagnostics")`](https://mattyoreilly.github.io/modelblueprint/articles/model-diagnostics.md)
  — using gain, pred_vs_obs, and residuals_grouped outside the dashboard
- [`vignette("partial-dependence-plots")`](https://mattyoreilly.github.io/modelblueprint/articles/partial-dependence-plots.md)
  — the
  [`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
  function in depth
- [`vignette("one-way-plots")`](https://mattyoreilly.github.io/modelblueprint/articles/one-way-plots.md)
  — the
  [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
  function in depth
