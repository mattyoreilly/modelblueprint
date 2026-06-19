# Render a SHAP dependence chart

Dual-axis Plotly chart that exactly mirrors
[`plot_pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/plot_pdp.md)
and `plot_one_way_simple()`:

- Left axis : yellow exposure bars

- Right axis : mean SHAP per bin (purple line + markers), zero reference
  line (dashed)

## Usage

``` r
plot_shap_dependence(agg, var, model_name)
```

## Arguments

- agg:

  data.table from
  [`aggregate_shap_bin()`](https://mattyoreilly.github.io/modelblueprint/reference/aggregate_shap_bin.md)
  with columns `.bin`, `mean_shap`, `exposure`.

- var:

  `[character(1)]` Feature name (x-axis label).

- model_name:

  `[character(1)]` Label used in the legend and title.

## Details

The x-axis uses
[`smart_level_order()`](https://mattyoreilly.github.io/modelblueprint/reference/smart_level_order.md)
so interval labels sort chronologically / numerically, matching
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
and
[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md).
