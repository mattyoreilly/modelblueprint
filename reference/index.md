# Package index

## The modelblueprint object

Create, predict from, persist, and manipulate a modelblueprint. A
modelblueprint wraps a fitted model together with its training data,
pipeline functions, and deployment metadata.

- [`modelblueprint`](https://mattyoreilly.github.io/modelblueprint/reference/ModelBlueprint.md)
  : modelblueprint: a model-agnostic container for ML model lifecycles
- [`predict(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/predict.ModelBlueprint.md)
  : Generate predictions from a modelblueprint
- [`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
  [`saveMB()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
  : Save a modelblueprint to disk
- [`loadmb()`](https://mattyoreilly.github.io/modelblueprint/reference/loadMB.md)
  [`loadMB()`](https://mattyoreilly.github.io/modelblueprint/reference/loadMB.md)
  : Load a modelblueprint from disk

## Data manipulation

dplyr-style verbs that operate on all data splits inside a
modelblueprint simultaneously, returning a new modelblueprint.

- [`filter(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/filter.ModelBlueprint.md)
  : Filter rows in a modelblueprint's datasets
- [`mutate(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/mutate.ModelBlueprint.md)
  : Mutate columns in a modelblueprint's datasets
- [`left_join(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/left_join.ModelBlueprint.md)
  : Left-join into a modelblueprint's datasets

## Model sequences

Chain multiple modelblueprints into a sequential pipeline where the
output of one model feeds the input of the next.

- [`mb_seq()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_seq.md)
  : A sequential pipeline of model layers

- [`mb_layer()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_layer.md)
  :

  Construct a single layer for use in an
  [`mb_seq()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_seq.md)

- [`predict(`*`<mb_seq>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/predict.mb_seq.md)
  : Generate predictions from an mb_seq

## Validation and diagnostics

Quantify model performance and calibration. All functions accept either
a modelblueprint (uses the stored data and model) or a plain data frame
(bring your own predictions).

- [`gain()`](https://mattyoreilly.github.io/modelblueprint/reference/gain.md)
  : Cumulative Gains Chart
- [`gain(`*`<default>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/gain.default.md)
  : Cumulative Gains Chart (default method)
- [`pred_vs_obs()`](https://mattyoreilly.github.io/modelblueprint/reference/pred_vs_obs.md)
  : Predicted vs Observed Calibration Plot
- [`residuals_grouped()`](https://mattyoreilly.github.io/modelblueprint/reference/residuals_grouped.md)
  : Grouped Residuals vs Predicted Plot

## Feature analysis

Understand how individual features relate to the target and drive model
predictions.

- [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
  : Create a one-way analysis plot
- [`one_way(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.ModelBlueprint.md)
  : One-way analysis for a modelblueprint
- [`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
  : Partial dependence plot for any predict()-compatible model
- [`pdp(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.ModelBlueprint.md)
  : Partial dependence plot for a modelblueprint
- [`shap()`](https://mattyoreilly.github.io/modelblueprint/reference/shap.md)
  : SHAP Feature Importance and Dependence Plots
- [`shap(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/shap.modelblueprint.md)
  : SHAP plots for a modelblueprint
- [`sami()`](https://mattyoreilly.github.io/modelblueprint/reference/sami.md)
  : SAMI Double Lift Chart

## Dashboard

Interactive Shiny app that combines all diagnostics and feature analysis
tools into a single four-tab interface.

- [`mb_dashboard()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md)
  : Launch an interactive dashboard for a modelblueprint

## Utilities

Helper functions useful in pre- and post-processing pipelines.

- [`unitise()`](https://mattyoreilly.github.io/modelblueprint/reference/unitise.md)
  : unitise a numeric variable to the range 0 to 1

## Example modelblueprints

Ready-made modelblueprint objects built on the `mtcars` dataset. Useful
for exploring the package without needing your own data.

- [`mb_lm_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_lm_classification()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_glm_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_glm_binomial()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_glm_poisson()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_rpart_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_rpart_classification()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_rf_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_rf_classification()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_xgb_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_xgb_classification()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_h2o_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_h2o_classification()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_h2o_glm_large()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  : Example modelblueprint objects
