# Bin a feature and aggregate mean SHAP value and exposure per bin

Uses
[`compute_bins()`](https://mattyoreilly.github.io/modelblueprint/reference/compute_bins.md)
from pdp.R to apply the same binning logic as
[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
and
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md),
then computes exposure-weighted mean SHAP and total exposure per bin.

## Usage

``` r
aggregate_shap_bin(feat_vals, shap_vals, expo_vals, bins, type_agg)
```

## Arguments

- feat_vals:

  `[numeric or character]` Raw feature values (length n).

- shap_vals:

  `[numeric]` SHAP values for this feature (length n).

- expo_vals:

  `[numeric]` Exposure weights (length n).

- bins:

  `[integer(1)]` Number of bins for numeric features.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

## Value

data.table with columns `.bin`, `mean_shap`, `exposure`.
