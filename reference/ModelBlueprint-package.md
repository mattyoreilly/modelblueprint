# modelblueprint: Model Diagnostics and Explainability for Machine Learning Workflows

A model-agnostic toolkit for exploring, diagnosing, and deploying
machine learning models. Wraps any fitted model (lm, glm, XGBoost, H2O,
random forests, and more) in a structured S7 object that carries
training data, feature engineering pipelines, and deployment metadata.
Provides one-way analysis plots, partial dependence plots (PDPs), SHAP
feature importance, cumulative gains charts, calibration plots, and
grouped residual diagnostics — all rendered as interactive Plotly
charts. Supports sequential model pipelines via mb_seq() and saves
complete model bundles (including H2O and XGBoost models) as portable
archives. Aggregation is handled by data.table and scales comfortably to
datasets of several million rows.

## See also

Useful links:

- <https://mattyoreilly.github.io/modelblueprint/>

## Author

**Maintainer**: Matt <fermoymatt@gmail.com>

Authors:

- Matt <fermoymatt@gmail.com>

- Hubert Ratajczyk <jane@example.com>
