# mb_seq.R
# A sequential pipeline of model layers. Each layer runs one or more
# modelblueprints, appends their predictions to the dataset, then passes
# the enriched dataset through an aggregation function that can add further
# derived columns (e.g. freq * sev, PD * EAD * LGD).


# =============================================================================
# mb_layer — S7 class
# =============================================================================

# Internal S7 class — constructed exclusively through mb_layer() below.
# Splitting the class definition (new_mb_layer_) from the user-facing
# constructor (mb_layer) follows the same pattern as modelblueprint /
# new_class so that validation logic with context-sensitive defaults lives in
# the constructor while structural invariants are enforced by the validator.
new_mb_layer_ <- new_class(
  "mb_layer",
  properties = list(
    blueprints   = new_property(class = class_list),
    aggregate_fn = new_property(class = class_function, default = function(df) df),
    yhat_name    = new_property(class = class_character, default = NA_character_)
  ),
  validator = function(self) {
    errors <- character()

    if (length(self@blueprints) == 0L) {
      # Early return: further checks would crash on zero-length input.
      return("@blueprints must be a non-empty list of modelblueprint objects.")
    }

    is_mb <- vapply(
      self@blueprints,
      function(b) inherits(b, "modelblueprint::modelblueprint"),
      logical(1L)
    )
    if (!all(is_mb)) {
      errors <- c(errors, "All elements of @blueprints must be modelblueprint objects.")
    }

    if (all(is_mb)) {
      has_yhat <- vapply(
        self@blueprints,
        function(b) !is.na(b@yhat_name) && nzchar(b@yhat_name),
        logical(1L)
      )
      if (!all(has_yhat)) {
        errors <- c(errors, "All blueprints must have @yhat_name set.")
      }

      # Duplicate yhat_names within a layer mean the later blueprint silently
      # overwrites the earlier one's prediction column at predict time.
      if (all(has_yhat)) {
        yhats <- vapply(
          self@blueprints,
          function(b) b@yhat_name,
          character(1L)
        )
        dupes <- unique(yhats[duplicated(yhats)])
        if (length(dupes) > 0L) {
          errors <- c(errors, sprintf(
            "Blueprints in a layer must have distinct @yhat_name values (duplicated: %s).",
            paste(dupes, collapse = ", ")
          ))
        }
      }
    }

    if (is.na(self@yhat_name) || !nzchar(self@yhat_name)) {
      errors <- c(errors, "@yhat_name must be a non-empty string.")
    }

    if (length(errors)) paste(errors, collapse = "\n")
  }
)


#' Construct a single layer for use in an [mb_seq()]
#'
#' A layer holds one or more `modelblueprint` objects that run in parallel.
#' Each blueprint appends its prediction (under `@yhat_name`) to the dataset.
#' `aggregate_fn` then receives the enriched dataset and can add further derived
#' columns. `yhat_name` declares the layer's primary output column -- this is
#' what `predict()` returns when `return_all = FALSE`, and what downstream
#' layers can reference as a feature.
#'
#' @param blueprints A list of `modelblueprint` objects. Every blueprint must
#'   have `@yhat_name` set.
#' @param aggregate_fn `function(df) -> df`. Receives the dataset after all blueprint
#'   predictions have been appended and returns it, optionally with additional
#'   columns. Defaults to the identity function when `blueprints` has one
#'   element; required when there are multiple blueprints.
#' @param yhat_name `[character(1)]` The primary output column of this layer.
#'   When `aggregate_fn` is `NULL`, defaults to the single blueprint's `@yhat_name`.
#'   When `aggregate_fn` is provided, set this to the column `aggregate_fn` adds that
#'   represents the layer's combined prediction.
#'
#' @return An `mb_layer` object.
#'
#' @examples
#' \dontrun{
#' # Single model -- aggregate_fn and yhat_name default to the blueprint's yhat_name
#' l1 <- mb_layer(list(mb_freq))
#'
#' # Two models combined as a product
#' l2 <- mb_layer(
#'   blueprints = list(mb_freq, mb_sev),
#'   yhat_name  = "pred_pure",
#'   aggregate_fn     = function(df) {
#'     df[["pred_pure"]] <- df[["pred_freq"]] * df[["pred_sev"]]
#'     df
#'   }
#' )
#' }
#'
#' @seealso [mb_seq()] to combine layers into a pipeline.
#' @export
mb_layer <- function(blueprints, aggregate_fn = NULL, yhat_name = NULL) {
  if (!is.list(blueprints) || length(blueprints) == 0L) {
    cli::cli_abort("{.arg blueprints} must be a non-empty list of modelblueprint objects.")
  }

  is_mb <- vapply(
    blueprints,
    function(b) inherits(b, "modelblueprint::modelblueprint"),
    logical(1L)
  )
  if (!all(is_mb)) {
    cli::cli_abort("All elements of {.arg blueprints} must be modelblueprint objects.")
  }

  has_yhat <- vapply(
    blueprints,
    function(b) !is.na(b@yhat_name) && nzchar(b@yhat_name),
    logical(1L)
  )
  if (!all(has_yhat)) {
    cli::cli_abort("All blueprints must have {.arg @yhat_name} set.")
  }

  if (!is.null(aggregate_fn) && !is.function(aggregate_fn)) {
    cli::cli_abort("{.arg aggregate_fn} must be a function.")
  }

  # For multiple blueprints, both aggregate_fn and yhat_name are required.
  # Check together so the user sees both errors at once.
  if (length(blueprints) > 1L) {
    errors <- character()
    if (is.null(aggregate_fn)) {
      errors <- c(errors, "{.arg aggregate_fn} is required when {.arg blueprints} has more than one element.")
    }
    if (is.null(yhat_name)) {
      errors <- c(errors, "{.arg yhat_name} is required when {.arg blueprints} has more than one element.")
    }
    if (length(errors)) cli::cli_abort(errors)
  }

  if (is.null(aggregate_fn)) aggregate_fn <- function(df) df
  if (is.null(yhat_name))    yhat_name    <- blueprints[[1L]]@yhat_name

  new_mb_layer_(
    blueprints   = blueprints,
    aggregate_fn = aggregate_fn,
    yhat_name    = yhat_name
  )
}


# -----------------------------------------------------------------------------
# print — dual S3 + S7 dispatch (same pattern as modelblueprint)
# -----------------------------------------------------------------------------

.print_mb_layer <- function(x) {
  cli::cli_text("<mb_layer>  output: {.val {x@yhat_name}}")
  for (mb in x@blueprints) {
    nm <- mb@model_display_name %|NA|% paste(class(mb@model)[[1L]], "model")
    cli::cli_text("  + {nm}  ->  {mb@yhat_name}")
  }
}

# S3 path: standard R dispatch (installed package, library(), etc.)
#' @keywords internal
#' @exportS3Method print mb_layer
print.mb_layer <- function(x, ...) {
  .print_mb_layer(x)
  invisible(x)
}

# S7 path: pkgload::load_all() routes through print.S7_object -> S7_dispatch()
method(print, new_mb_layer_) <- function(x, ...) {
  .print_mb_layer(x)
  invisible(x)
}


# =============================================================================
# mb_seq — S7 class
# =============================================================================

new_mb_seq_ <- new_class(
  "mb_seq",
  properties = list(
    layers             = new_property(class = class_list),
    train              = new_property(class = class_tabular, default = NULL),
    test               = new_property(class = class_tabular, default = NULL),
    holdout            = new_property(class = class_tabular, default = NULL),
    y_name             = new_property(class = class_character, default = NA_character_),
    expo_name          = new_property(class = class_character, default = NA_character_),
    model_display_name = new_property(class = class_character, default = NA_character_)
  ),
  validator = function(self) {
    errors <- character()

    if (length(self@layers) == 0L) {
      errors <- c(errors, "@layers must contain at least one mb_layer.")
    } else {
      is_layer <- vapply(
        self@layers,
        function(l) inherits(l, "modelblueprint::mb_layer"),
        logical(1L)
      )
      if (!all(is_layer)) {
        errors <- c(errors, "All elements of @layers must be mb_layer objects created by mb_layer().")
      }
    }

    if (length(errors)) paste(errors, collapse = "\n")
  }
)


#' A sequential pipeline of model layers
#'
#' `mb_seq` chains one or more `mb_layer` objects together. Each layer runs
#' after the previous one, receiving a dataset enriched with all predictions
#' produced so far. This allows later layers to use earlier predictions as
#' input features.
#'
#' At construction time, `mb_seq` validates that every blueprint's required
#' columns (`@x_original_inputs`, `@expo_name`, `@offset_name`) are present
#' in the supplied data at the point that blueprint would run -- accounting for
#' the fact that earlier layers add new columns.
#'
#' @param ... One or more `mb_layer` objects, in execution order.
#' @param train,test,holdout Data frames for model development and evaluation.
#' @param y_name `[character(1)]` Final target variable name. Used by
#'   diagnostic functions.
#' @param expo_name `[character(1)]` Exposure column name. Default `NA`.
#' @param model_display_name `[character(1)]` Human-readable label.
#'
#' @return An `mb_seq` object.
#'
#' @examples
#' \dontrun{
#' # Pure premium: frequency * severity
#' seq_ps <- mb_seq(
#'   mb_layer(
#'     blueprints = list(mb_freq, mb_sev),
#'     yhat_name  = "pred_pure",
#'     aggregate_fn     = function(df) {
#'       df[["pred_pure"]] <- df[["pred_freq"]] * df[["pred_sev"]]
#'       df
#'     }
#'   ),
#'   train              = df_train,
#'   y_name             = "burn_cost",
#'   expo_name          = "earned_premium",
#'   model_display_name = "pure_premium"
#' )
#'
#' # Expected loss: PD x EAD x LGD
#' seq_el <- mb_seq(
#'   mb_layer(
#'     blueprints = list(mb_pd, mb_ead, mb_lgd),
#'     yhat_name  = "pred_el",
#'     aggregate_fn     = function(df) {
#'       df[["pred_el"]] <- df[["pred_pd"]] * df[["pred_ead"]] * df[["pred_lgd"]]
#'       df
#'     }
#'   ),
#'   train  = df_train,
#'   y_name = "actual_loss"
#' )
#'
#' # Sequential: GLM output feeds XGBoost as a feature
#' seq_chain <- mb_seq(
#'   mb_layer(list(mb_glm)),
#'   mb_layer(list(mb_xgb)),
#'   train  = df_train,
#'   y_name = "target"
#' )
#' }
#'
#' @seealso [mb_layer()] to construct individual layers, [predict.mb_seq()]
#'   for generating predictions.
#' @export
mb_seq <- function(...,
                   train              = NULL,
                   test               = NULL,
                   holdout            = NULL,
                   y_name             = NA_character_,
                   expo_name          = NA_character_,
                   model_display_name = NA_character_) {
  layers <- list(...)

  is_layer <- vapply(
    layers,
    function(l) inherits(l, "modelblueprint::mb_layer"),
    logical(1L)
  )
  if (!all(is_layer)) {
    cli::cli_abort(
      "All positional arguments to {.fn mb_seq} must be {.cls mb_layer} objects.",
      i = "Did you pass a list? Use {.code do.call(mb_seq, your_list)} instead."
    )
  }

  ref_data <- train %||% test %||% holdout
  if (!is.null(ref_data)) {
    validate_seq_columns(layers, ref_data, y_name, expo_name)
  }

  new_mb_seq_(
    layers             = layers,
    train              = train,
    test               = test,
    holdout            = holdout,
    y_name             = y_name,
    expo_name          = expo_name,
    model_display_name = model_display_name
  )
}


#' @keywords internal
#' @noRd
validate_seq_columns <- function(layers, data, y_name, expo_name) {
  available <- names(data)

  if (!is.na(y_name) && !y_name %in% available) {
    cli::cli_abort("Column {.val {y_name}} ({.arg y_name}) not found in the dataset.")
  }
  if (!is.na(expo_name) && !expo_name %in% available) {
    cli::cli_abort("Column {.val {expo_name}} ({.arg expo_name}) not found in the dataset.")
  }

  for (i in seq_along(layers)) {
    lyr <- layers[[i]]

    for (mb in lyr@blueprints) {
      nm      <- mb@model_display_name %|NA|% paste(class(mb@model)[[1L]], "model")
      missing <- setdiff(stats::na.omit(mb@x_original_inputs), available)

      if (length(missing) > 0L) {
        cli::cli_abort(c(
          "Layer {i}, blueprint {.val {nm}}: required column{?s} not available.",
          x = "Missing: {.val {missing}}",
          i = "If the missing column(s) come from an earlier layer, check that the preceding layer's {.arg yhat_name} matches."
        ))
      }

      if (!is.na(mb@expo_name) && !mb@expo_name %in% available) {
        cli::cli_abort(
          "Layer {i}, blueprint {.val {nm}}: exposure column {.val {mb@expo_name}} not found."
        )
      }

      if (!is.na(mb@offset_name) && !mb@offset_name %in% available) {
        cli::cli_abort(
          "Layer {i}, blueprint {.val {nm}}: offset column {.val {mb@offset_name}} not found."
        )
      }
    }

    bp_yhats  <- vapply(lyr@blueprints, function(mb) mb@yhat_name, character(1L))
    available <- union(available, c(bp_yhats, lyr@yhat_name))
  }

  invisible(NULL)
}


#' Generate predictions from an mb_seq
#'
#' Runs each layer in sequence, appending blueprint predictions and aggregation
#' outputs to the dataset as it goes.
#'
#' @param object An `mb_seq` object.
#' @param newdata A data frame or data.table.
#' @param return_all `[logical(1)]` If `FALSE` (default), returns the final
#'   layer's primary output as a numeric vector. If `TRUE`, returns a data
#'   frame containing all prediction columns added across all layers.
#' @param ... Unused.
#'
#' @return A numeric vector (`return_all = FALSE`) or a data frame of all
#'   prediction columns (`return_all = TRUE`).
#' @export
predict.mb_seq <- function(object, newdata, return_all = FALSE, ...) {
  if (missing(newdata) || is.null(newdata)) {
    cli::cli_abort("{.arg newdata} is required.")
  }

  df        <- as.data.frame(newdata)
  pred_cols <- character()

  for (i in seq_along(object@layers)) {
    lyr <- object@layers[[i]]

    for (mb in lyr@blueprints) {
      df[[mb@yhat_name]] <- predict(mb, df)
      pred_cols <- c(pred_cols, mb@yhat_name)
    }

    prev_cols <- names(df)
    df <- tryCatch(
      lyr@aggregate_fn(df),
      error = function(e) {
        cli::cli_abort(c("Layer {i} {.fn aggregate_fn} failed.", x = conditionMessage(e)))
      }
    )
    if (!is.data.frame(df)) {
      cli::cli_abort(c(
        "Layer {i} {.fn aggregate_fn} must return a data frame.",
        i = "Add columns to {.arg df} and return it, rather than returning a vector."
      ))
    }

    new_cols  <- setdiff(names(df), prev_cols)
    pred_cols <- c(pred_cols, new_cols)
  }

  # unique(): a later layer's aggregate_fn may legitimately overwrite a column
  # added by an earlier layer, in which case pred_cols records the name twice.
  if (return_all) return(df[unique(pred_cols)])

  df[[object@layers[[length(object@layers)]]@yhat_name]]
}


method(print, new_mb_seq_) <- function(x, ...) {
  nm <- x@model_display_name %|NA|% "mb_seq"
  n  <- length(x@layers)
  cli::cli_text("<mb_seq>  {.val {nm}}  ({n} layer{?s})")

  sets <- c(
    if (!is.null(x@train))   "train",
    if (!is.null(x@test))    "test",
    if (!is.null(x@holdout)) "holdout"
  )
  if (length(sets)) cli::cli_text("  datasets: {.val {sets}}")

  for (i in seq_along(x@layers)) {
    lyr  <- x@layers[[i]]
    n_bp <- length(lyr@blueprints)
    cli::cli_text("  Layer {i} ({n_bp} blueprint{?s})  ->  {.val {lyr@yhat_name}}")
    for (mb in lyr@blueprints) {
      nm_mb <- mb@model_display_name %|NA|% paste(class(mb@model)[[1L]], "model")
      cli::cli_text("    + {nm_mb}  ->  {mb@yhat_name}")
    }
  }
  invisible(x)
}
