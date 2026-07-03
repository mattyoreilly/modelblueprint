# modelblueprint 1.6.1

## Bug fixes

* `residuals_grouped()` now computes bin midpoints directly from the numeric
  break points instead of re-parsing `cut()` labels. Previously, labels in
  scientific notation (small prediction rates) produced meaningless midpoints.
* `gain()` drops rows with missing obs/pred/exposure values (with a warning)
  before building the cumulative curve. Previously a single `NA` truncated
  the curve silently from that row onward.
* `one_way()` and `pdp()` weighted bin means are no longer deflated when the
  target contains `NA`s: each mean's denominator now counts only the exposure
  of rows where that value is non-missing.
* `model_predict()` rejects H2O multinomial models with a clear error instead
  of silently returning factor level codes.
* `pred_vs_obs()` and `residuals_grouped()` default methods fall back to unit
  weights when the exposure column is absent (matching `one_way()` and
  `gain()`), and validate the obs/pred columns up front.
* `pdp()` on a `modelblueprint` keeps the `@offset_name` column when narrowing
  the working dataset, so models fit with `offset()` predict correctly.
* `predict()` on an `mb_seq` with `return_all = TRUE` no longer returns
  duplicated columns, and `mb_layer()` rejects blueprints with duplicate
  `@yhat_name`s (the later one silently overwrote the earlier).
* The x-axis ordering of interval labels now understands scientific notation.
* Gains charts support more than 12 competing scores (palette interpolation).
* The example xgboost blueprints use the current `xgboost()` interface; the
  suggested xgboost version floor is now `>= 3.0.0`.

## Improvements

* Zero-exposure rows are replaced with `@expo_0_rep` (with a warning) before
  the rate division in `gain()`, `pred_vs_obs()`, and `residuals_grouped()`
  on a `modelblueprint` — previously the property was documented but unused
  and zero exposure produced `Inf` rates.
* `pdp()` and `one_way()` gained a `verbose` argument (default `FALSE`);
  per-call progress and NA-relocation messages are now opt-in.
* Hover text no longer shows `Inf%`/`NaN%` when a reference mean is zero.
* `filter()`, `mutate()`, and `left_join()` generics are re-exported, so the
  modelblueprint methods work without attaching dplyr.
* `savemb()` on an `mb_seq` fails with an informative message (serialisation
  of sequences is not yet supported).

# modelblueprint 1.6.0

* First public release: `modelblueprint` S7 container, `one_way()`, `pdp()`,
  `shap()`, `gain()`, `pred_vs_obs()`, `residuals_grouped()`, `sami()`,
  `mb_seq()` pipelines, `savemb()`/`loadmb()` persistence, and
  `mb_dashboard()`.
