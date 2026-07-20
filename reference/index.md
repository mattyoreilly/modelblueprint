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

## Accessors and updaters

Tidy `extract_*` and `set_*` verbs for reading and replacing individual
slots. Each `set_*` returns a new modelblueprint — never mutates in
place — and runs the S7 validator automatically.

- [`extract_fit()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_fit.md)
  : Extract the fitted model from a modelblueprint
- [`extract_train()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_splits.md)
  [`extract_test()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_splits.md)
  [`extract_holdout()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_splits.md)
  : Extract a data split from a modelblueprint
- [`extract_pre_process_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_pipeline.md)
  [`extract_feat_eng_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_pipeline.md)
  [`extract_post_process_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_pipeline.md)
  : Extract pipeline functions from a modelblueprint
- [`extract_original_inputs()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_features.md)
  [`extract_feature_names()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_features.md)
  : Extract feature name vectors from a modelblueprint
- [`extract_target()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_yhat_name()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_exposure_name()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_exposure_value()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_exposure_zero_rep()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_offset_name()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_offset_value()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_display_name()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  [`extract_deploy_notes()`](https://mattyoreilly.github.io/modelblueprint/reference/extract_metadata.md)
  : Extract scalar metadata from a modelblueprint
- [`set_model()`](https://mattyoreilly.github.io/modelblueprint/reference/set_model.md)
  : Swap the fitted model inside a modelblueprint
- [`set_train()`](https://mattyoreilly.github.io/modelblueprint/reference/set_splits.md)
  [`set_test()`](https://mattyoreilly.github.io/modelblueprint/reference/set_splits.md)
  [`set_holdout()`](https://mattyoreilly.github.io/modelblueprint/reference/set_splits.md)
  : Replace a data split in a modelblueprint
- [`set_pre_process_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/set_pipeline.md)
  [`set_feat_eng_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/set_pipeline.md)
  [`set_post_process_fun()`](https://mattyoreilly.github.io/modelblueprint/reference/set_pipeline.md)
  : Replace pipeline functions in a modelblueprint
- [`set_original_inputs()`](https://mattyoreilly.github.io/modelblueprint/reference/set_features.md)
  [`set_feature_names()`](https://mattyoreilly.github.io/modelblueprint/reference/set_features.md)
  : Replace feature name vectors in a modelblueprint
- [`set_target()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_yhat_name()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_exposure_name()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_exposure_value()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_exposure_zero_rep()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_offset_name()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_offset_value()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_display_name()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  [`set_deploy_notes()`](https://mattyoreilly.github.io/modelblueprint/reference/set_metadata.md)
  : Set scalar metadata on a modelblueprint

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
- [`distribution()`](https://mattyoreilly.github.io/modelblueprint/reference/distribution.md)
  : Plot the distribution of the target variable
- [`distribution(`*`<modelblueprint>`*`)`](https://mattyoreilly.github.io/modelblueprint/reference/distribution.modelblueprint.md)
  : Target distribution for a modelblueprint
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

## Batch validation

Generate and save a full suite of validation, one-way, PDP, stability,
and SHAP plots for every dataset split in a single call.

- [`model_validation()`](https://mattyoreilly.github.io/modelblueprint/reference/model_validation.md)
  : Generate and save model validation plots

## Dashboard

Interactive Shiny app that combines all diagnostics and feature analysis
tools into a single four-tab interface.

- [`mb_dashboard()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md)
  : Launch an interactive dashboard for a modelblueprint

## Utilities

Helper functions useful in pre- and post-processing pipelines.

- [`unitise()`](https://mattyoreilly.github.io/modelblueprint/reference/unitise.md)
  : unitise a numeric variable to the range 0 to 1
- [`save_plots()`](https://mattyoreilly.github.io/modelblueprint/reference/save_plots.md)
  : Save plots or HTML widgets to a single HTML file

## Example modelblueprints

Ready-made modelblueprint objects for exploring the package without
needing your own data. Includes regression, classification, Poisson
frequency (car insurance), random forest, XGBoost, and H2O examples.

- [`mb_lm_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_lm_classification()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_glm_regression()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_glm_binomial()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_glm_poisson()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
  [`mb_glm_poisson_freq()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_examples.md)
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
