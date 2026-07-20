# Changelog

## modelblueprint 1.6.4

### New features

- New
  [`distribution()`](https://mattyoreilly.github.io/modelblueprint/reference/distribution.md)
  plots the exposure-weighted distribution of the target variable as a
  plotly bar chart. It mirrors
  [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)’s
  interface (bare or quoted column names, `split`, `bins`, `time_unit`,
  `type_agg`, `ret`) and reuses its binning and NA handling; a
  `modelblueprint` method pulls the target and exposure from the
  blueprint’s slots.

## modelblueprint 1.6.3

### Bug fixes

- Constructing or validating a `modelblueprint` no longer fails on R \<
  4.3 with `trying to get slot ... that is not an S4 object`. S7 only
  exports its `@` operator on R \< 4.3 (base R handles S7 `@` natively
  from 4.3), and the package did not import it, so every property access
  inside package code fell through to base’s S4 slot operator on older
  R.

### Infrastructure

- Declared minimum R version raised from 4.1.0 to 4.2.0 to match what CI
  actually verifies (an R 4.2.2 job mirroring the Azure ML deployment
  target).
- H2O tests are skipped on CI runners, where the H2O JVM is unstable,
  and run in a weekly scheduled workflow instead (set
  `MB_RUN_H2O_TESTS=1` to force them on).

## modelblueprint 1.6.2

### New features

- [`gain()`](https://mattyoreilly.github.io/modelblueprint/reference/gain.md),
  [`pred_vs_obs()`](https://mattyoreilly.github.io/modelblueprint/reference/pred_vs_obs.md)
  and
  [`residuals_grouped()`](https://mattyoreilly.github.io/modelblueprint/reference/residuals_grouped.md)
  on a `modelblueprint` now default to **all available sets**
  (train/test/holdout) instead of silently using only train. With more
  than one set they return a named list with one result per set; a
  single `set` returns the bare plot as before.

### Bug fixes

- [`save_plots()`](https://mattyoreilly.github.io/modelblueprint/reference/save_plots.md)
  with `selfcontained = FALSE` now writes dependency links that resolve
  correctly. Previously the dependency folder was created nested inside
  the output directory a second time, and plots rendered blank once the
  output tree was moved or cleaned.
- [`save_plots()`](https://mattyoreilly.github.io/modelblueprint/reference/save_plots.md)
  gains a shareable `libdir`:
  [`model_validation()`](https://mattyoreilly.github.io/modelblueprint/reference/model_validation.md)
  uses it so all HTML files in each output subdirectory share a single
  `lib/` dependency folder instead of one folder per file.
- [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
  on a `modelblueprint` with multiple variables omits skipped variables
  (e.g. \>2,000 unique non-numeric levels) from the returned list
  instead of including `NULL` entries that broke
  [`save_plots()`](https://mattyoreilly.github.io/modelblueprint/reference/save_plots.md).

## modelblueprint 1.6.1

### Bug fixes

- [`residuals_grouped()`](https://mattyoreilly.github.io/modelblueprint/reference/residuals_grouped.md)
  now computes bin midpoints directly from the numeric break points
  instead of re-parsing [`cut()`](https://rdrr.io/r/base/cut.html)
  labels. Previously, labels in scientific notation (small prediction
  rates) produced meaningless midpoints.
- [`gain()`](https://mattyoreilly.github.io/modelblueprint/reference/gain.md)
  drops rows with missing obs/pred/exposure values (with a warning)
  before building the cumulative curve. Previously a single `NA`
  truncated the curve silently from that row onward.
- [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
  and
  [`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
  weighted bin means are no longer deflated when the target contains
  `NA`s: each mean’s denominator now counts only the exposure of rows
  where that value is non-missing.
- [`model_predict()`](https://mattyoreilly.github.io/modelblueprint/reference/model_predict.md)
  rejects H2O multinomial models with a clear error instead of silently
  returning factor level codes.
- [`pred_vs_obs()`](https://mattyoreilly.github.io/modelblueprint/reference/pred_vs_obs.md)
  and
  [`residuals_grouped()`](https://mattyoreilly.github.io/modelblueprint/reference/residuals_grouped.md)
  default methods fall back to unit weights when the exposure column is
  absent (matching
  [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
  and
  [`gain()`](https://mattyoreilly.github.io/modelblueprint/reference/gain.md)),
  and validate the obs/pred columns up front.
- [`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
  on a `modelblueprint` keeps the `@offset_name` column when narrowing
  the working dataset, so models fit with
  [`offset()`](https://rdrr.io/r/stats/offset.html) predict correctly.
- [`predict()`](https://rdrr.io/r/stats/predict.html) on an `mb_seq`
  with `return_all = TRUE` no longer returns duplicated columns, and
  [`mb_layer()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_layer.md)
  rejects blueprints with duplicate `@yhat_name`s (the later one
  silently overwrote the earlier).
- The x-axis ordering of interval labels now understands scientific
  notation.
- Gains charts support more than 12 competing scores (palette
  interpolation).
- The example xgboost blueprints use the current `xgboost()` interface;
  the suggested xgboost version floor is now `>= 3.0.0`.

### Improvements

- Zero-exposure rows are replaced with `@expo_0_rep` (with a warning)
  before the rate division in
  [`gain()`](https://mattyoreilly.github.io/modelblueprint/reference/gain.md),
  [`pred_vs_obs()`](https://mattyoreilly.github.io/modelblueprint/reference/pred_vs_obs.md),
  and
  [`residuals_grouped()`](https://mattyoreilly.github.io/modelblueprint/reference/residuals_grouped.md)
  on a `modelblueprint` — previously the property was documented but
  unused and zero exposure produced `Inf` rates.
- [`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
  and
  [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
  gained a `verbose` argument (default `FALSE`); per-call progress and
  NA-relocation messages are now opt-in.
- Hover text no longer shows `Inf%`/`NaN%` when a reference mean is
  zero.
- [`filter()`](https://dplyr.tidyverse.org/reference/filter.html),
  [`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html), and
  [`left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
  generics are re-exported, so the modelblueprint methods work without
  attaching dplyr.
- [`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
  on an `mb_seq` fails with an informative message (serialisation of
  sequences is not yet supported).

## modelblueprint 1.6.0

- First public release: `modelblueprint` S7 container,
  [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md),
  [`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md),
  [`shap()`](https://mattyoreilly.github.io/modelblueprint/reference/shap.md),
  [`gain()`](https://mattyoreilly.github.io/modelblueprint/reference/gain.md),
  [`pred_vs_obs()`](https://mattyoreilly.github.io/modelblueprint/reference/pred_vs_obs.md),
  [`residuals_grouped()`](https://mattyoreilly.github.io/modelblueprint/reference/residuals_grouped.md),
  [`sami()`](https://mattyoreilly.github.io/modelblueprint/reference/sami.md),
  [`mb_seq()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_seq.md)
  pipelines,
  [`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)/[`loadmb()`](https://mattyoreilly.github.io/modelblueprint/reference/loadMB.md)
  persistence, and
  [`mb_dashboard()`](https://mattyoreilly.github.io/modelblueprint/reference/mb_dashboard.md).
