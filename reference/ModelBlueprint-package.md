# modelblueprint: One-Way and Partial Dependence Plots for Models

Provides fast, production-ready one-way analysis plots and partial
dependence plots (PDPs) designed for insurance and credit pricing
workflows. One-way plots show exposure-weighted means of one or more
observed variables across bins of a feature, with optional split
grouping. PDP plots reveal the marginal effect of a feature on model
output, controlling for all other features, and work with any model that
implements a predict() method including H2O models. All plots use a
consistent dual-axis Plotly style: yellow exposure bars on the left axis
and weighted means on the right. Aggregation is handled by data.table
and scales comfortably to datasets of 1-2 million rows.

## See also

Useful links:

- <https://matt-or.github.io/modelblueprint/>

## Author

**Maintainer**: Matt <fermoymatt@gmail.com>

Authors:

- Matt <fermoymatt@gmail.com>
