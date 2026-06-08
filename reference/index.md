# Package index

## All functions

- [`modelblueprint`](ModelBlueprint.md) : modelblueprint: a
  model-agnostic container for ML model lifecycles

- [`filter(`*`<modelblueprint>`*`)`](filter.ModelBlueprint.md) : Filter
  rows in a modelblueprint's datasets

- [`gain()`](gain.md) : Cumulative Gains Chart

- [`gain(`*`<default>`*`)`](gain.default.md) : Cumulative Gains Chart
  (default method)

- [`left_join(`*`<modelblueprint>`*`)`](left_join.ModelBlueprint.md) :
  Left-join into a modelblueprint's datasets

- [`loadMB()`](loadMB.md) : Load a modelblueprint from disk

- [`mb_dashboard()`](mb_dashboard.md) : Launch an interactive dashboard
  for a modelblueprint

- [`mb_lm_regression()`](mb_examples.md)
  [`mb_lm_classification()`](mb_examples.md)
  [`mb_glm_regression()`](mb_examples.md)
  [`mb_glm_binomial()`](mb_examples.md)
  [`mb_glm_poisson()`](mb_examples.md)
  [`mb_rpart_regression()`](mb_examples.md)
  [`mb_rpart_classification()`](mb_examples.md)
  [`mb_rf_regression()`](mb_examples.md)
  [`mb_rf_classification()`](mb_examples.md)
  [`mb_xgb_regression()`](mb_examples.md)
  [`mb_xgb_classification()`](mb_examples.md)
  [`mb_h2o_regression()`](mb_examples.md)
  [`mb_h2o_classification()`](mb_examples.md) : Example modelblueprint
  objects

- [`mb_layer()`](mb_layer.md) :

  Construct a single layer for use in an
  [`mb_seq()`](../reference/mb_seq.md)

- [`mb_seq()`](mb_seq.md) : A sequential pipeline of model layers

- [`mutate(`*`<modelblueprint>`*`)`](mutate.ModelBlueprint.md) : Mutate
  columns in a modelblueprint's datasets

- [`one_way(`*`<modelblueprint>`*`)`](one_way.ModelBlueprint.md) :
  One-way analysis for a modelblueprint

- [`one_way()`](one_way.md) : Create a one-way analysis plot

- [`one_way_nse()`](one_way_nse.md) : NSE wrapper for one_way

- [`pdp(`*`<modelblueprint>`*`)`](pdp.ModelBlueprint.md) : Partial
  dependence plot for a modelblueprint

- [`pdp()`](pdp.md) : Partial dependence plot for any
  predict()-compatible model

- [`pred_vs_obs()`](pred_vs_obs.md) : Predicted vs Observed Calibration
  Plot

- [`predict(`*`<modelblueprint>`*`)`](predict.ModelBlueprint.md) :
  Generate predictions from a modelblueprint

- [`predict(`*`<mb_seq>`*`)`](predict.mb_seq.md) : Generate predictions
  from an mb_seq

- [`residuals_grouped()`](residuals_grouped.md) : Grouped Residuals vs
  Predicted Plot

- [`sami()`](sami.md) : SAMI Double Lift Chart

- [`saveMB()`](saveMB.md) : Save a modelblueprint to disk

- [`unitise()`](unitise.md) : unitise a numeric variable to the range 0
  to 1
