# Partial dependence plots

## What is a partial dependence plot?

A partial dependence plot (PDP) reveals the **marginal effect** of a
single feature on model output, averaging out the influence of all other
features. Unlike a one-way plot — which shows raw observed and predicted
means per bin — a PDP fixes a feature at a series of values and averages
predictions across the full training distribution.

This makes PDPs especially useful for:

- Understanding non-linear feature effects in black-box models
- Comparing the shape of a relationship across competing models
- Diagnosing interactions and unexpected behaviour

The chart has the same dual-axis layout as one-way plots:

- **Yellow bars (right axis)** — exposure per bin
- **Three lines (left axis)** — observed mean, in-sample predicted mean,
  and PDP (marginal effect)

## Basic usage

``` r

library(modelblueprint)

mb <- mb_glm_binomial()

# PDP for wt — everything pulled from blueprint slots
pdp(mb, var = "wt")
```

On a plain data frame:

``` r

model <- glm(vs ~ wt + hp, data = mtcars, family = binomial)
pdp(mtcars, var = "wt", obs = "vs", model = model)
```

## Understanding the three lines

The PDP chart shows three lines per feature:

- **Observed** — exposure-weighted mean of the actual target per bin.
  This is the same as the one-way plot.
- **Predicted (in-sample)** — exposure-weighted mean of
  `predict(model, data)` per bin. Tracks the observed line when the
  model is well-calibrated.
- **PDP** — the true marginal effect. For each bin midpoint, the feature
  is fixed at that value across **all rows** of the training data and
  predictions are averaged. This isolates the feature’s contribution
  from correlations with other features.

When the PDP line diverges from the predicted line, it signals that the
feature’s in-sample predictions are driven partly by correlations rather
than the feature itself.

## Controlling bins and sample size

``` r

# Coarser view
pdp(mb, var = "wt", bins = 5L)

# Finer view — slower for large models
pdp(mb, var = "wt", bins = 20L)
```

PDP computation requires predicting across the full dataset for each
bin. For large datasets, `sample_size` caps the number of rows used:

``` r

# Use at most 1,000 rows for PDP computation
pdp(mb, var = "wt", sample_size = 1000L)
```

The default is 10,000. For most models, 1,000 rows gives a stable PDP
line at a fraction of the computation cost.

## Binning strategy

``` r

pdp(mb, var = "wt", type_agg = "equal_range")
```

## Choosing the dataset

``` r

pdp(mb, var = "wt", set = "train")
pdp(mb, var = "wt", set = "test")    # out-of-sample PDP
```

Computing the PDP on the test set is a useful check — if the PDP shape
changes substantially from train to test, the model may be overfitting
to correlations present only in training data.

## Returning the data

``` r

d <- pdp(mb, var = "wt", ret = "data")
head(d)
```

Columns returned:

| Column        | Description                               |
|---------------|-------------------------------------------|
| `wt`          | Bin label (interval string or level name) |
| `obs_mean`    | Exposure-weighted observed mean           |
| `pred_mean`   | Exposure-weighted predicted mean          |
| `pdp_mean`    | Marginal PDP value                        |
| `exposure`    | Total exposure in bin                     |
| `global_obs`  | Dataset-wide observed mean                |
| `global_pred` | Dataset-wide predicted mean               |

## Compatible model types

[`pdp()`](../reference/pdp.md) works with any model that implements
[`predict()`](https://rdrr.io/r/stats/predict.html):

``` r

# GLM — response scale (probabilities for binomial)
pdp(mb_glm_binomial(), var = "wt")

# Random forest
pdp(mb_rf_regression(), var = "wt")

# XGBoost
pdp(mb_xgb_regression(), var = "wt")

# H2O
pdp(mb_h2o_regression(), var = "wt")
```

For H2O models, [`pdp()`](../reference/pdp.md) connects to the running
H2O cluster automatically and handles the H2OFrame conversion
internally.

## Interpreting PDPs

A flat PDP line means the feature has little marginal effect — the model
ignores it once other features are controlled for. A sloping line means
the feature drives predictions in that direction across the full data
distribution, not just where it correlates with other predictors.

For binary classification models, PDP values are probabilities. A PDP
that rises from 0.1 to 0.6 across the feature range means the model
assigns substantially higher probability of the positive class at higher
feature values.
