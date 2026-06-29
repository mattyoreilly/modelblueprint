# =============================================================================
# extract.R
# Tidy accessor (extract_*) and functional-update (set_*) verbs for
# modelblueprint. Mirrors the pattern established by tidymodels/parsnip:
#   extract_*() — retrieve a slot; always returns the raw value.
#   set_*()     — return a modified copy; pipe-friendly, runs S7 validation.
# =============================================================================

NULL


# =============================================================================
# Helpers
# =============================================================================

.check_mb <- function(x, call = rlang::caller_env()) {
  if (!S7::S7_inherits(x, modelblueprint)) {
    cli::cli_abort("{.arg x} must be a {.cls modelblueprint}.", call = call)
  }
}


.check_fun <- function(value, arg, call = rlang::caller_env()) {
  if (!is.function(value)) {
    cli::cli_abort("{.arg {arg}} must be a function.", call = call)
  }
}

.check_chr <- function(value, arg, call = rlang::caller_env()) {
  if (!is.character(value)) {
    cli::cli_abort("{.arg {arg}} must be a character vector.", call = call)
  }
}

.check_scalar_chr <- function(value, arg, call = rlang::caller_env()) {
  if (!is.character(value) || length(value) != 1L) {
    cli::cli_abort("{.arg {arg}} must be a single string.", call = call)
  }
}

.check_tabular <- function(value, arg, call = rlang::caller_env()) {
  if (!is.data.frame(value) && !inherits(value, "data.table")) {
    cli::cli_abort(
      "{.arg {arg}} must be a data.frame or data.table.",
      call = call
    )
  }
}


# =============================================================================
# extract_fit  ----------------------------------------------------------------
# Returns the raw fitted model object (no pipeline, no wrapper).
# Named extract_fit() to mirror tidymodels' extract_fit_engine() convention:
# the "fit" is the engine-level object, not a parsnip shell.
# =============================================================================

#' Extract the fitted model from a modelblueprint
#'
#' Returns the raw model object stored in `@model` — the thing you would pass
#' directly to `predict()`, `coef()`, `summary()`, etc.
#'
#' @param x A `modelblueprint`.
#' @param ... Unused; reserved for subclass methods.
#' @return The fitted model object.
#' @seealso [set_model()]
#' @export
extract_fit <- function(x, ...) UseMethod("extract_fit")

#' @export
extract_fit.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@model
}


# =============================================================================
# extract_train / extract_test / extract_holdout  -----------------------------
# =============================================================================

#' Extract a data split from a modelblueprint
#'
#' @param x A `modelblueprint`.
#' @param ... Unused.
#' @return A `data.frame` / `data.table`, or `NULL` if the split was not set.
#' @name extract_splits
#' @seealso [set_train()], [set_test()], [set_holdout()]
NULL

#' @rdname extract_splits
#' @export
extract_train <- function(x, ...) UseMethod("extract_train")

#' @export
extract_train.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@train
}

#' @rdname extract_splits
#' @export
extract_test <- function(x, ...) UseMethod("extract_test")

#' @export
extract_test.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@test
}

#' @rdname extract_splits
#' @export
extract_holdout <- function(x, ...) UseMethod("extract_holdout")

#' @export
extract_holdout.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@holdout
}


# =============================================================================
# extract_pre_process_fun / extract_feat_eng_fun / extract_post_process_fun  ----
# Pipeline function accessors — named after their role, not their slot.
# =============================================================================

#' Extract pipeline functions from a modelblueprint
#'
#' @param x A `modelblueprint`.
#' @param ... Unused.
#' @return The pipeline function.
#' @name extract_pipeline
#' @seealso [set_pre_process_fun()], [set_feat_eng_fun()], [set_post_process_fun()]
NULL

#' @rdname extract_pipeline
#' @export
extract_pre_process_fun <- function(x, ...) UseMethod("extract_pre_process_fun")

#' @export
extract_pre_process_fun.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@pre_process_fun
}

#' @rdname extract_pipeline
#' @export
extract_feat_eng_fun <- function(x, ...) UseMethod("extract_feat_eng_fun")

#' @export
extract_feat_eng_fun.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@feat_eng_fun
}

#' @rdname extract_pipeline
#' @export
extract_post_process_fun <- function(x, ...) UseMethod("extract_post_process_fun")

#' @export
extract_post_process_fun.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@post_process_fun
}


# =============================================================================
# extract_original_inputs / extract_feature_names  ----------------------------
# =============================================================================

#' Extract feature name vectors from a modelblueprint
#'
#' `extract_original_inputs()` returns `@x_original_inputs` — the column names
#' present in the raw data before any feature engineering.
#' `extract_feature_names()` returns `@x_names` — the names after feature
#' engineering (i.e. what the model actually sees).
#'
#' @param x A `modelblueprint`.
#' @param ... Unused.
#' @return A character vector, with `NA_character_` values removed.
#' @name extract_features
#' @seealso [set_original_inputs()], [set_feature_names()]
NULL

#' @rdname extract_features
#' @export
extract_original_inputs <- function(x, ...) UseMethod("extract_original_inputs")

#' @export
extract_original_inputs.modelblueprint <- function(x, ...) {
  .check_mb(x)
  stats::na.omit(x@x_original_inputs)
}

#' @rdname extract_features
#' @export
extract_feature_names <- function(x, ...) UseMethod("extract_feature_names")

#' @export
extract_feature_names.modelblueprint <- function(x, ...) {
  .check_mb(x)
  stats::na.omit(x@x_names)
}


# =============================================================================
# Metadata scalar extractors  -------------------------------------------------
# =============================================================================

#' Extract scalar metadata from a modelblueprint
#'
#' @param x A `modelblueprint`.
#' @param ... Unused.
#' @return The slot value (`NA` when not set).
#' @name extract_metadata
NULL

#' @rdname extract_metadata
#' @export
extract_target <- function(x, ...) UseMethod("extract_target")

#' @export
extract_target.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@y_name
}

#' @rdname extract_metadata
#' @export
extract_yhat_name <- function(x, ...) UseMethod("extract_yhat_name")

#' @export
extract_yhat_name.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@yhat_name
}

#' @rdname extract_metadata
#' @export
extract_exposure_name <- function(x, ...) UseMethod("extract_exposure_name")

#' @export
extract_exposure_name.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@expo_name
}

#' @rdname extract_metadata
#' @export
extract_exposure_value <- function(x, ...) UseMethod("extract_exposure_value")

#' @export
extract_exposure_value.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@expo_val
}

#' @rdname extract_metadata
#' @export
extract_exposure_zero_rep <- function(x, ...) UseMethod("extract_exposure_zero_rep")

#' @export
extract_exposure_zero_rep.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@expo_0_rep
}

#' @rdname extract_metadata
#' @export
extract_offset_name <- function(x, ...) UseMethod("extract_offset_name")

#' @export
extract_offset_name.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@offset_name
}

#' @rdname extract_metadata
#' @export
extract_offset_value <- function(x, ...) UseMethod("extract_offset_value")

#' @export
extract_offset_value.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@offset_value
}

#' @rdname extract_metadata
#' @export
extract_display_name <- function(x, ...) UseMethod("extract_display_name")

#' @export
extract_display_name.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@model_display_name
}

#' @rdname extract_metadata
#' @export
extract_deploy_notes <- function(x, ...) UseMethod("extract_deploy_notes")

#' @export
extract_deploy_notes.modelblueprint <- function(x, ...) {
  .check_mb(x)
  x@deploy_notes
}


# =============================================================================
# set_* verbs  ----------------------------------------------------------------
# Each returns a *new* modelblueprint — never mutates in place.
# prop<-() triggers S7 class validation, so cross-property checks (e.g.
# y_name != yhat_name) run automatically.
# =============================================================================

#' Swap the fitted model inside a modelblueprint
#'
#' Returns a new `modelblueprint` with `@model` replaced by `value`. Use this
#' after retraining to keep all pipeline functions and metadata intact.
#'
#' @param x     A `modelblueprint`.
#' @param value A fitted model object.
#' @param ...   Unused.
#' @return A new `modelblueprint`.
#' @seealso [extract_fit()]
#' @export
set_model <- function(x, value, ...) UseMethod("set_model")

#' @export
set_model.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  prop(x, "model") <- value
  x
}


#' Replace a data split in a modelblueprint
#'
#' @param x     A `modelblueprint`.
#' @param value A `data.frame` or `data.table`.
#' @param ...   Unused.
#' @return A new `modelblueprint`.
#' @name set_splits
#' @seealso [extract_train()], [extract_test()], [extract_holdout()]
NULL

#' @rdname set_splits
#' @export
set_train <- function(x, value, ...) UseMethod("set_train")

#' @export
set_train.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_tabular(value, "value")
  prop(x, "train") <- value
  x
}

#' @rdname set_splits
#' @export
set_test <- function(x, value, ...) UseMethod("set_test")

#' @export
set_test.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_tabular(value, "value")
  prop(x, "test") <- value
  x
}

#' @rdname set_splits
#' @export
set_holdout <- function(x, value, ...) UseMethod("set_holdout")

#' @export
set_holdout.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_tabular(value, "value")
  prop(x, "holdout") <- value
  x
}


#' Replace pipeline functions in a modelblueprint
#'
#' @param x     A `modelblueprint`.
#' @param value A function with the expected signature for that pipeline stage.
#' @param ...   Unused.
#' @return A new `modelblueprint`.
#' @name set_pipeline
#' @seealso [extract_pre_process_fun()], [extract_feat_eng_fun()],
#'   [extract_post_process_fun()]
NULL

#' @rdname set_pipeline
#' @export
set_pre_process_fun <- function(x, value, ...) UseMethod("set_pre_process_fun")

#' @export
set_pre_process_fun.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_fun(value, "value")
  prop(x, "pre_process_fun") <- value
  x
}

#' @rdname set_pipeline
#' @export
set_feat_eng_fun <- function(x, value, ...) UseMethod("set_feat_eng_fun")

#' @export
set_feat_eng_fun.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_fun(value, "value")
  prop(x, "feat_eng_fun") <- value
  x
}

#' @rdname set_pipeline
#' @export
set_post_process_fun <- function(x, value, ...) UseMethod("set_post_process_fun")

#' @export
set_post_process_fun.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_fun(value, "value")
  prop(x, "post_process_fun") <- value
  x
}


#' Replace feature name vectors in a modelblueprint
#'
#' @param x     A `modelblueprint`.
#' @param value A character vector of column names.
#' @param ...   Unused.
#' @return A new `modelblueprint`.
#' @name set_features
#' @seealso [extract_original_inputs()], [extract_feature_names()]
NULL

#' @rdname set_features
#' @export
set_original_inputs <- function(x, value, ...) UseMethod("set_original_inputs")

#' @export
set_original_inputs.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_chr(value, "value")
  prop(x, "x_original_inputs") <- value
  x
}

#' @rdname set_features
#' @export
set_feature_names <- function(x, value, ...) UseMethod("set_feature_names")

#' @export
set_feature_names.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_chr(value, "value")
  prop(x, "x_names") <- value
  x
}


#' Set scalar metadata on a modelblueprint
#'
#' @param x     A `modelblueprint`.
#' @param value A single string (or numeric for `set_exposure_value` /
#'   `set_exposure_zero_rep` / `set_offset_value`).
#' @param ...   Unused.
#' @return A new `modelblueprint`.
#' @name set_metadata
NULL

#' @rdname set_metadata
#' @export
set_target <- function(x, value, ...) UseMethod("set_target")

#' @export
set_target.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_scalar_chr(value, "value")
  prop(x, "y_name") <- value
  x
}

#' @rdname set_metadata
#' @export
set_yhat_name <- function(x, value, ...) UseMethod("set_yhat_name")

#' @export
set_yhat_name.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_scalar_chr(value, "value")
  prop(x, "yhat_name") <- value
  x
}

#' @rdname set_metadata
#' @export
set_exposure_name <- function(x, value, ...) UseMethod("set_exposure_name")

#' @export
set_exposure_name.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_scalar_chr(value, "value")
  prop(x, "expo_name") <- value
  x
}

#' @rdname set_metadata
#' @export
set_exposure_value <- function(x, value, ...) UseMethod("set_exposure_value")

#' @export
set_exposure_value.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  if (!is.numeric(value) || length(value) != 1L) {
    cli::cli_abort("{.arg value} must be a single number.")
  }
  prop(x, "expo_val") <- value
  x
}

#' @rdname set_metadata
#' @export
set_exposure_zero_rep <- function(x, value, ...) UseMethod("set_exposure_zero_rep")

#' @export
set_exposure_zero_rep.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  if (!is.numeric(value) || length(value) != 1L) {
    cli::cli_abort("{.arg value} must be a single number.")
  }
  prop(x, "expo_0_rep") <- value
  x
}

#' @rdname set_metadata
#' @export
set_offset_name <- function(x, value, ...) UseMethod("set_offset_name")

#' @export
set_offset_name.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_scalar_chr(value, "value")
  prop(x, "offset_name") <- value
  x
}

#' @rdname set_metadata
#' @export
set_offset_value <- function(x, value, ...) UseMethod("set_offset_value")

#' @export
set_offset_value.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  if (!is.numeric(value) || length(value) != 1L) {
    cli::cli_abort("{.arg value} must be a single number or NA.")
  }
  prop(x, "offset_value") <- value
  x
}

#' @rdname set_metadata
#' @export
set_display_name <- function(x, value, ...) UseMethod("set_display_name")

#' @export
set_display_name.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_scalar_chr(value, "value")
  prop(x, "model_display_name") <- value
  x
}

#' @rdname set_metadata
#' @export
set_deploy_notes <- function(x, value, ...) UseMethod("set_deploy_notes")

#' @export
set_deploy_notes.modelblueprint <- function(x, value, ...) {
  .check_mb(x)
  .check_scalar_chr(value, "value")
  prop(x, "deploy_notes") <- value
  x
}
