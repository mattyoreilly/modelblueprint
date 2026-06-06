# modelblueprint

<!-- badges: start -->
[![R-CMD-check](https://github.com/matt/modelblueprint/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/matt/modelblueprint/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

**modelblueprint** is a model-agnostic container for managing machine learning model lifecycles in R. Wrap any `predict()`-compatible model — `lm`, `glm`, XGBoost, H2O, and more — with its training data, pipeline functions, and metadata, then run diagnostics with a single function call.

## Installation

```r
# Install from GitHub
pak::pak("mattyoreilly/modelblueprint")
```

## Overview

```r
library(modelblueprint)

mb <- modelblueprint(
  model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train  = mtcars,
  y_name = "vs",
  expo_name          = "exposure",
  model_display_name = "logistic_vs"
)

# Predict
predict(mb, mtcars)

# One-way analysis — pulled directly from blueprint slots
one_way(mb, var = "wt")

# Partial dependence plot
pdp(mb, var = "wt")

# Gains chart with Gini coefficient
gain(mb)

# Calibration chart
pred_vs_obs(mb)

# Grouped residuals with loess trend
residuals_grouped(mb)

# Save and restore
saveMB(mb, path = "models/", filename = "logistic_vs")
mb2 <- loadMB("models/logistic_vs.tar.gz")
```

## Key features

- **Model-agnostic** — works with any R model implementing `predict()`, including H2O
- **Pipe-friendly** — `filter()`, `mutate()`, and `left_join()` methods return new blueprints
- **Diagnostic plots** — one-way, PDP, gains, calibration, and residual plots built in
- **Persistence** — save and restore full model pipelines including H2O models
- **S7 class system** — type-safe properties with informative validation errors

## Supported models

| Model | Package | Regression | Classification |
|---|---|---|---|
| Linear model | base R | ✓ | ✓ (LPM) |
| GLM (Gaussian, Binomial, Poisson) | base R | ✓ | ✓ |
| Decision tree | rpart | ✓ | ✓ |
| Random forest | randomForest | ✓ | ✓ |
| Gradient boosting | xgboost | ✓ | ✓ |
| H2O GLM / GBM / AutoML | h2o | ✓ | ✓ |
| Any `predict()`-compatible model | — | ✓ | ✓ |
