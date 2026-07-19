# =============================================================================
# zzz.R
# Package-level declarations loaded last by R's source-file ordering.
# =============================================================================


# =============================================================================
# globalVariables — suppress R CMD check NOTEs for data.table NSE
#
# Consolidated here so you can see every suppressed name and which file
# actually uses it. Adding a name here does NOT suppress legitimate "object
# not found" errors at run time — it only silences the static check NOTE.
# =============================================================================

utils::globalVariables(c(
  # ── data.table internal column names (.dt-style dots) ─────────────────────
  # Created with := inside [ ] and never present in the caller's data.
  ".",           # data.table's special `.` pronoun
  ".bin",        # pdp.R, shap.R, hosmer.R   — bin index
  ".bin_group",  # pdp.R                     — grouped bin key
  ".expo",       # one_way.R, pdp.R, hosmer.R, residuals_grouped.R — exposure col
  ".expo_col",   # pdp.R                     — exposure column alias
  ".expo_shap",  # shap.R                    — exposure for SHAP aggregation
  ".obs",        # hosmer.R, residuals_grouped.R — observed target alias
  ".obs_col",    # pdp.R                     — observed column alias
  ".pdp_pred",   # pdp.R                     — PDP prediction scratch col
  ".pred",       # pdp.R, hosmer.R, residuals_grouped.R — prediction alias
  ".shap",       # shap.R                    — SHAP value column
  ".split",      # one_way.R, pdp.R          — split-group column
  ".val",        # pdp.R                     — feature value scratch col
  ".var",        # one_way.R, pdp.R          — variable being analysed
  ".w",          # one_way.R, pdp.R          — weight column
  ".wobs",       # pdp.R                     — weighted observation scratch
  ".wobs_den",   # pdp.R                     — obs denominator (non-NA exposure)
  ".wpred",      # pdp.R                     — weighted prediction scratch
  ".wpred_den",  # pdp.R                     — pred denominator (non-NA exposure)
  ".x_bin",      # one_way.R, pdp.R          — binned feature value

  # ── Aggregation output column names ───────────────────────────────────────
  # Produced by data.table summarisation and referenced in subsequent steps.
  "bin",         # residuals_grouped.R       — bin label
  "exposure",    # one_way.R, pdp.R, hosmer.R — resolved exposure column
  "left",        # hosmer.R                  — lower interval bound from binning
  "loe_low",     # residuals_grouped.R       — loess lower CI
  "loe_pred",    # residuals_grouped.R       — loess fitted value
  "loe_upp",     # residuals_grouped.R       — loess upper CI
  "midpoint",    # residuals_grouped.R       — bin midpoint
  "obs_mean",    # pdp.R, hosmer.R, residuals_grouped.R — weighted obs mean
  "obs_sum",     # hosmer.R, residuals_grouped.R         — sum of observed
  "pred_mean",   # pdp.R, hosmer.R, residuals_grouped.R — weighted pred mean
  "pred_sum",    # hosmer.R, residuals_grouped.R         — sum of predicted
  "rate",        # residuals_grouped.R       — residual rate
  "res",         # residuals_grouped.R       — residual value
  "right",       # hosmer.R                  — upper interval bound from binning

  # ── Other NSE names ────────────────────────────────────────────────────────
  "perfect_model",  # gain.R     — perfect-model baseline column
  "ratio_col",      # sami.R     — ratio column produced inside sami.default()

  # ── S7 property names ─────────────────────────────────────────────────────
  # On R < 4.3, `x@name` parses as a call to S7's imported `@` function, so
  # the 4.2 checker reads each property name as an undefined global and emits
  # ~20 "no visible binding" NOTEs. Modern R parses `@` as syntax and never
  # flags these. Names mirror the modelblueprint / mb_seq property lists.
  "model", "train", "test", "holdout",
  "pre_process_fun", "feat_eng_fun", "post_process_fun",
  "x_original_inputs", "x_names", "y_name", "yhat_name",
  "expo_name", "expo_val", "expo_0_rep",
  "offset_name", "offset_value",
  "model_display_name", "deploy_notes",
  "blueprints", "layers", "aggregate_fn"
))
