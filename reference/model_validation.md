# Generate and save model validation plots

Runs a configurable set of diagnostic and feature-analysis plots for
each requested dataset split and writes the results to structured HTML
files inside a directory named after `@model_display_name`.

## Usage

``` r
model_validation(
  mb,
  sets = c("train", "test", "holdout"),
  plots = c("validation", "oneway", "pdp", "stability", "shap"),
  validation_bins = 10L,
  one_way_bins = 10L,
  pdp_bins = 10L,
  split = NA_character_,
  filepath = getwd(),
  selfcontained = TRUE
)
```

## Arguments

- mb:

  A `modelblueprint` object.

- sets:

  `[character]` Dataset splits to process. Default
  `c("train", "test", "holdout")`. NULL splits are silently skipped.

- plots:

  `[character]` Plot types to produce. Any combination of
  `"validation"`, `"oneway"`, `"pdp"`, `"stability"`, `"shap"`.

- validation_bins:

  `[integer(1)]` Bins for gain / pred-vs-obs charts. Default `10L`.

- one_way_bins:

  `[integer(1)]` Bins for one-way charts. Default `10L`.

- pdp_bins:

  `[integer(1)]` Bins for PDP charts. Default `10L`.

- split:

  `[character(1)]` Column name to segment one-way plots by. `NA`
  (default) produces unsplit charts.

- filepath:

  `[character(1)]` Parent directory for all output. Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html). A subdirectory named
  `@model_display_name` is created inside.

- selfcontained:

  `[logical(1)]` Passed to
  [`save_plots()`](https://mattyoreilly.github.io/modelblueprint/reference/save_plots.md).
  `TRUE` (default) embeds all dependencies into each HTML file. Set to
  `FALSE` for faster saves during development.

## Value

The root output directory path, invisibly.

## Details

**Output layout**

    <filepath>/
      <model_display_name>/
        <name>.tar.gz
        validation/
          <name>_<set>_validation_plots.html
        oneway/
          <name>_<set>_oneway_plots.html
          <name>_<set>_stability_plots.html   # if "stability" requested
        pdp/
          <name>_<set>_pdp_plots.html
        shap/
          <name>_<set>_shap_plots.html

**Validation** plots include a gain chart, predicted-vs-observed
calibration chart, and grouped residuals — one HTML file per split.

**One-way** plots cover every feature in `@x_original_inputs`. If
`split` is supplied the column is passed to
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md);
otherwise charts are unsplit.

**Stability** plots are one-way charts split by a random 50/50 variable
(`"A"` / `"B"`). If the two lines overlap closely the patterns are
stable and not driven by random noise.

**PDP** plots cover every feature in `@x_original_inputs`.

**SHAP** plots use
[`shap()`](https://mattyoreilly.github.io/modelblueprint/reference/shap.md)
with `type = "importance"`. The modelblueprint must have
`@x_original_inputs` set and the model must support kernel SHAP.

The modelblueprint itself is serialised via
[`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
into the root output directory.

## See also

[`gain()`](https://mattyoreilly.github.io/modelblueprint/reference/gain.md),
[`pred_vs_obs()`](https://mattyoreilly.github.io/modelblueprint/reference/pred_vs_obs.md),
[`residuals_grouped()`](https://mattyoreilly.github.io/modelblueprint/reference/residuals_grouped.md),
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md),
[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md),
[`shap()`](https://mattyoreilly.github.io/modelblueprint/reference/shap.md),
[`save_plots()`](https://mattyoreilly.github.io/modelblueprint/reference/save_plots.md),
[`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
