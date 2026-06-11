# Compute PDP values for each bin

For each bin, fixes the feature at its midpoint (numeric) or label
(categorical), runs predictions across the full sample, and returns the
mean prediction.

## Usage

``` r
compute_pdp(
  rep_set,
  var,
  bin_info,
  expo_col,
  model,
  pre_process_fun,
  feat_eng_fun,
  post_process_fun
)
```

## Value

data.table with columns: .bin, pdp_mean
