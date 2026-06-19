# Render SHAP feature importance chart

Horizontal bar chart of **mean SHAP** (signed) per feature, sorted by
magnitude (mean \|SHAP\|) so the most influential feature is at the top.
Purple bars indicate a feature whose average effect **increases** the
prediction; blue bars indicate a feature that **decreases** it. A zero
reference line and colour legend subtitle make the direction immediately
readable.

## Usage

``` r
plot_shap_importance(imp, model_name)
```

## Arguments

- imp:

  data.frame with columns `feature`, `mean_shap`, and `mean_abs_shap`.

- model_name:

  `[character(1)]` Label shown in the chart title.

## Details

Styling matches
[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
and
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md):
transparent background, same margins, `hovermode = "y unified"`.
