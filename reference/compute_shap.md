# Permutation-based SHAP value computation

For each feature `j` in `vars` and each observation `i`, runs `nsim`
random permutations of the `vars` feature ordering. In permutation `s`:

- `vars` features appearing *before* `j` (the "coalition") keep actual
  values; `vars` features at `j` and after are swapped to a background
  row for `without_j`, while `with_j` keeps `j` actual but swaps
  features after `j`.

- Non-`vars` columns always retain their actual observation values so
  the model can find every column it was trained on.

- The marginal contribution is pred(with_j) - pred(without_j). Averaging
  over permutations gives an unbiased Shapley value estimate.

## Usage

``` r
compute_shap(
  X_full,
  model,
  vars,
  nsim,
  pre_process_fun,
  feat_eng_fun,
  post_process_fun
)
```

## Arguments

- X_full:

  data.frame of rows to explain - ALL columns the model needs, not just
  `vars`.

- model:

  Fitted model object.

- vars:

  `[character]` Names of the features whose SHAP values are computed.
  Must be columns of `X_full`.

- nsim:

  `[integer(1)]` Permutations per observation.

- pre_process_fun:

  Pre-processing pipeline function.

- feat_eng_fun:

  Feature-engineering pipeline function.

- post_process_fun:

  Post-processing pipeline function.

## Value

data.frame with the same row count as `X_full` and one column per
element of `vars` containing the SHAP values.

## Details

All `2 * n * nsim` rows for a single feature are stacked into one
data.frame and passed to
[`model_predict()`](https://mattyoreilly.github.io/modelblueprint/reference/model_predict.md)
in a single call, following the same batch-predict pattern as
[`compute_pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/compute_pdp.md).
