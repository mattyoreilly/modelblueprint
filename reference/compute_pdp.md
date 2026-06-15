# Compute PDP values for each bin (batch approach)

Replicates the sample once per bin into a single large data.table,
stamps each block with the corresponding bin value, then calls predict()
exactly once. Group-averaging over blocks gives the PDP mean per bin.

## Usage

``` r
compute_pdp(
  rep_set,
  var,
  bin_info,
  all_bins,
  expo_col,
  model,
  pre_process_fun,
  feat_eng_fun,
  post_process_fun
)
```

## Value

data.table with columns: .bin, pdp_mean

## Details

For models with per-call overhead (H2O HTTP round-trips, remote
endpoints, XGBoost DMatrix construction) this is typically 5-20x faster
than calling predict() once per bin in a loop.

Memory cost: sample_size \* n_bins rows. At 10,000 rows x 15 bins that
is 150,000 rows — well within reason for a typical dataset.
