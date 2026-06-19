# =============================================================================
# modelblueprint.R
# S7 class for managing the full lifecycle of a machine learning model.
# =============================================================================

NULL


# =============================================================================
# modelblueprint S7 class
# =============================================================================

#' modelblueprint: a model-agnostic container for ML model lifecycles
#'
#' @param model A fitted model object. Any class implementing `predict()`.
#' @param train,test,holdout Datasets as `data.frame`. Default `NULL`.
#' @param pre_process_fun `function(df) -> df`. Pre-processing pipeline.
#' @param feat_eng_fun `function(df) -> df`. Feature engineering pipeline.
#' @param post_process_fun `function(preds, df_raw) -> numeric`. Post-processing.
#' @param x_original_inputs `[character]` Original input feature names.
#' @param x_names `[character]` Engineered feature names.
#' @param y_name `[character(1)]` Target variable name.
#' @param yhat_name `[character(1)]` Prediction column name.
#' @param expo_name `[character(1)]` Exposure column name.
#' @param expo_val `[numeric(1)]` Reference exposure value.
#' @param expo_0_rep `[numeric(1)]` Replacement for zero-exposure rows.
#' @param offset_name `[character(1)]` Offset variable name.
#' @param offset_value `[numeric(1)]` Offset value.
#' @param model_display_name `[character(1)]` Human-readable label.
#' @param deploy_notes `[character(1)]` Deployment notes.
#'
#' @examples
#' \dontrun{
#' mb <- modelblueprint(
#'   model  = lm(mpg ~ wt + hp, data = mtcars),
#'   train  = mtcars,
#'   y_name = "mpg"
#' )
#' predict(mb, mtcars)
#' }
#'
#' @usage NULL
#' @export
modelblueprint <- new_class(
  name = "modelblueprint",

  properties = list(
    model = new_property(
      class = class_any,
      validator = function(value) {
        if (is.null(value)) "must supply a fitted model object"
      }
    ),
    train = new_property(class = class_tabular, default = NULL),
    test = new_property(class = class_tabular, default = NULL),
    holdout = new_property(class = class_tabular, default = NULL),

    pre_process_fun = new_property(
      class = class_function,
      default = function(df) df
    ),
    feat_eng_fun = new_property(
      class = class_function,
      default = function(df) df
    ),
    post_process_fun = new_property(
      class = class_function,
      default = function(preds, df_raw) preds
    ),

    x_original_inputs = new_property(
      class = class_character,
      default = NA_character_
    ),
    x_names = new_property(class = class_character, default = NA_character_),
    y_name = new_property(class = class_character, default = NA_character_),
    yhat_name = new_property(class = class_character, default = NA_character_),
    expo_name = new_property(class = class_character, default = "exposure"),
    expo_val = new_property(class = class_numeric, default = 1),
    expo_0_rep = new_property(class = class_numeric, default = 0.1),
    offset_name = new_property(
      class = class_character,
      default = NA_character_
    ),
    offset_value = new_property(class = class_numeric, default = NA_real_),
    model_display_name = new_property(
      class = class_character,
      default = NA_character_
    ),
    deploy_notes = new_property(
      class = class_character,
      default = NA_character_
    )
  ),

  validator = function(self) {
    errors <- character(0)
    if (length(errors) > 0L) paste(errors, collapse = "\n")
  }
)


# =============================================================================
# predict method
# =============================================================================

#' Generate predictions from a modelblueprint
#'
#' Applies `pre_process_fun` -> `feat_eng_fun` -> model prediction ->
#' `post_process_fun` to `newdata`.
#'
#' @param object  A `modelblueprint`.
#' @param newdata A `data.frame` or `data.table`.
#' @param ...     Unused.
#' @return A numeric vector of predictions.
#' @export
predict.modelblueprint <- function(object, newdata, ...) {
  if (missing(newdata) || is.null(newdata)) {
    cli::cli_abort("{.arg newdata} is required for prediction.")
  }
  if (!is.data.frame(newdata) && !inherits(newdata, "data.table")) {
    cli::cli_abort("{.arg newdata} must be a data.frame or data.table.")
  }

  tmp <- if (inherits(newdata, "data.table")) {
    data.table::copy(newdata)
  } else {
    as.data.frame(newdata)
  }

  tmp <- object@pre_process_fun(tmp)
  tmp <- object@feat_eng_fun(tmp)
  raw_preds <- model_predict(object@model, tmp)
  object@post_process_fun(raw_preds, newdata)
}


# =============================================================================
# print method
# =============================================================================

# Shared implementation — called by both dispatch paths below.
.print_modelblueprint <- function(x) {
  rule <- function(ch = "-", n = 60L) paste(rep(ch, n), collapse = "")
  cat(rule("="), "\n")
  cat("modelblueprint\n")
  cat(rule("="), "\n")
  cat(sprintf("  Model:        %s\n", paste(class(x@model), collapse = "/")))
  cat(sprintf("  Display name: %s\n", x@model_display_name %||% "<not set>"))
  cat(sprintf("  Target:       %s\n", x@y_name %||% "<not set>"))
  cat(sprintf("  Exposure:     %s (val = %s)\n", x@expo_name, x@expo_val))
  cat(sprintf(
    "  Features:     %d original / %d engineered\n",
    length(stats::na.omit(x@x_original_inputs)),
    length(stats::na.omit(x@x_names))
  ))
  cat(rule("-"), "\n")
  cat(sprintf("  Train rows:   %s\n", format_nrow(x@train)))
  cat(sprintf("  Test rows:    %s\n", format_nrow(x@test)))
  cat(sprintf("  Holdout rows: %s\n", format_nrow(x@holdout)))
  if (!is.na(x@deploy_notes)) {
    cat(rule("-"), "\n")
    cat(sprintf("  Notes: %s\n", x@deploy_notes))
  }
  cat(rule("="), "\n")
}

# S3 path: standard R dispatch (installed package, library(), etc.)
#' @keywords internal
#' @exportS3Method print modelblueprint
print.modelblueprint <- function(x, ...) {
  .print_modelblueprint(x)
  invisible(x)
}

# S7 path: pkgload::load_all() routes through print.S7_object -> S7_dispatch()
method(print, modelblueprint) <- function(x, ...) {
  .print_modelblueprint(x)
  invisible(x)
}

format_nrow <- function(d) {
  if (is.null(d)) "<not set>" else format(nrow(d), big.mark = ",")
}


# =============================================================================
# dplyr-style methods
# =============================================================================

#' Filter rows in a modelblueprint's datasets
#' @param .data A `modelblueprint`.
#' @param ... Filter expressions passed to `dplyr::filter()`.
#' @param sets Which datasets to filter. Default: all non-NULL.
#' @return A new `modelblueprint`.
#' @method filter modelblueprint
#' @export
filter.modelblueprint <- function(
  .data,
  ...,
  sets = c("train", "test", "holdout")
) {
  sets <- sets[vapply(sets, function(s) !is.null(prop(.data, s)), logical(1L))]
  mb <- .data
  for (s in sets) {
    prop(mb, s) <- dplyr::filter(prop(mb, s), ...)
  }
  mb
}

#' Mutate columns in a modelblueprint's datasets
#' @param .data A `modelblueprint`.
#' @param ... Expressions passed to `dplyr::mutate()`.
#' @param sets Which datasets to mutate. Default: all non-NULL.
#' @return A new `modelblueprint`.
#' @method mutate modelblueprint
#' @export
mutate.modelblueprint <- function(
  .data,
  ...,
  sets = c("train", "test", "holdout")
) {
  sets <- sets[vapply(sets, function(s) !is.null(prop(.data, s)), logical(1L))]
  mb <- .data
  for (s in sets) {
    prop(mb, s) <- dplyr::mutate(prop(mb, s), ...)
  }
  mb
}

#' Left-join into a modelblueprint's datasets
#' @param x A `modelblueprint`.
#' @param y A `data.frame` to join.
#' @param by Join keys.
#' @param sets Which datasets to join. Default: all non-NULL.
#' @param ... Passed to `dplyr::left_join()`.
#' @return A new `modelblueprint`.
#' @method left_join modelblueprint
#' @export
left_join.modelblueprint <- function(
  x,
  y,
  by = NULL,
  ...,
  sets = c("train", "test", "holdout")
) {
  sets <- sets[vapply(sets, function(s) !is.null(prop(x, s)), logical(1L))]
  mb <- x
  for (s in sets) {
    prop(mb, s) <- dplyr::left_join(prop(mb, s), y, by = by, ...)
  }
  mb
}


# =============================================================================
# saveMB
# =============================================================================

#' Save a modelblueprint to disk
#'
#' Serialises a `modelblueprint` to a compressed `.tar.gz` archive containing
#' all components needed to fully reconstruct it: model, data splits, pipeline
#' functions, and metadata.
#'
#' @param object   A `modelblueprint` object.
#' @param path     Directory to write the archive to. Default: working directory.
#' @param filename Optional filename. When `NULL`, `model_display_name` is used.
#' @param ...      Currently unused. Reserved for future subclass methods.
#' @return Invisibly returns the full normalised path to the saved archive.
#' @seealso [loadMB()]
#' @export
saveMB <- new_generic(
  "saveMB",
  "object",
  function(object, path = getwd(), filename = NULL, ...) S7_dispatch()
)

method(saveMB, modelblueprint) <- function(
  object,
  path = getwd(),
  filename = NULL
) {
  if (is.null(filename)) {
    filename <- prop(object, "model_display_name")
    if (is.na(filename) || !nzchar(filename)) {
      cli::cli_abort(
        "{.arg filename} must be supplied when {.arg model_display_name} is not set."
      )
    }
  }
  if (tools::file_ext(filename) == "") {
    filename <- paste0(filename, ".tar.gz")
  }
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
  }

  tmp <- file.path(tempdir(), paste0("saveMB_", as.integer(Sys.time())))
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  # Save class metadata so loadMB() can reconstruct the right class.
  # This is what allows loadMB() to be a plain function that works for both
  # modelblueprint and any future subclass (modelblueprintSequence etc.)
  saveRDS(
    list(
      class = class(object),
      version = utils::packageVersion("modelblueprint")
    ),
    file = file.path(tmp, "meta.rds"),
    compress = FALSE
  )

  all_props <- props(object)
  for (prop_name in names(all_props)) {
    val <- all_props[[prop_name]]
    if (is.null(val)) {
      next
    }
    if (is.atomic(val) && length(val) == 1L && is.na(val)) {
      next
    }

    if (prop_name == "model") {
      save_model_slot(val, tmp)
    } else if (prop_name %in% c("train", "test", "holdout")) {
      save_data_slot(val, prop_name, tmp)
    } else {
      saveRDS(
        val,
        file = file.path(tmp, paste0(prop_name, ".rds")),
        compress = FALSE
      )
    }
  }

  tarfile <- tools::file_path_sans_ext(tools::file_path_sans_ext(filename))
  withr::with_dir(tmp, utils::tar(tarfile, files = ".", compression = "gzip"))

  final_path <- file.path(path, basename(filename))
  file.copy(file.path(tmp, tarfile), final_path, overwrite = TRUE)
  message(sprintf("modelblueprint saved: %s", normalizePath(final_path)))
  invisible(normalizePath(final_path))
}


# =============================================================================
# loadMB
# =============================================================================

#' Load a modelblueprint from disk
#'
#' Reconstructs a `modelblueprint` from a `.tar.gz` archive created by [saveMB()].
#'
#' @param path Path to the `.tar.gz` archive created by [saveMB()].
#' @return A fully reconstructed `modelblueprint` object.
#' @seealso [saveMB()]
#' @export
loadMB <- function(path) {
  if (!file.exists(path)) {
    cli::cli_abort("Archive not found: {.path {path}}")
  }

  tmp <- file.path(tempdir(), paste0("loadMB_", as.integer(Sys.time())))
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::untar(path, exdir = tmp)

  meta_path <- file.path(tmp, "meta.rds")
  if (!file.exists(meta_path)) {
    message("Note: archive has no metadata; assuming modelblueprint class.")
    return(load_modelblueprint(tmp))
  }

  meta <- readRDS(meta_path)

  # Add a new branch here when modelblueprintSequence is introduced.
  # S7 stores the class as "modelblueprint::modelblueprint" (package-qualified).
  # Strip the package prefix before switching so both bare and qualified names work.
  bare_class <- sub("^.*::", "", meta$class[[1L]])

  switch(
    bare_class,
    modelblueprint = load_modelblueprint(tmp),
    cli::cli_abort(
      "Don't know how to load class {.val {bare_class}}. Is the right package version installed?"
    )
  )
}


# =============================================================================
# Internal helpers
# =============================================================================

#' @keywords internal
save_model_slot <- function(model, tmp) {
  bundled <- tryCatch(
    bundle::bundle(model),
    error = function(e) {
      cli::cli_warn(c(
        "bundle::bundle() failed for this model type; falling back to plain saveRDS().",
        i = "Predictions may not survive serialisation for models with external references (H2O, XGBoost, etc.).",
        x = conditionMessage(e)
      ))
      NULL
    }
  )
  saveRDS(
    if (is.null(bundled)) model else bundled,
    file     = file.path(tmp, "r_model.rds"),
    compress = FALSE
  )
}

#' @keywords internal
load_modelblueprint <- function(tmp) {
  args <- list()
  args[["model"]] <- load_model_slot(tmp)

  for (slot_name in c("train", "test", "holdout")) {
    loaded <- load_data_slot(slot_name, tmp)
    if (!is.null(loaded)) args[[slot_name]] <- loaded
  }

  skip <- c(
    "r_model.rds",
    "meta.rds",
    paste0(c("train", "test", "holdout"), "_factor_info.rds")
  )
  rds_files <- list.files(tmp, pattern = "\\.rds$", full.names = TRUE)
  rds_files <- rds_files[!basename(rds_files) %in% skip]
  for (f in rds_files) {
    args[[tools::file_path_sans_ext(basename(f))]] <- readRDS(f)
  }

  do.call(modelblueprint, args)
}

#' @keywords internal
load_model_slot <- function(tmp) {
  r_model_path <- file.path(tmp, "r_model.rds")
  if (!file.exists(r_model_path)) {
    cli::cli_abort("Archive is missing the model file ({.file r_model.rds}).")
  }
  obj <- readRDS(r_model_path)
  if (inherits(obj, "bundle")) bundle::unbundle(obj) else obj
}

#' @keywords internal
save_data_slot <- function(df, slot_name, tmp) {
  if (is.null(df) || nrow(df) == 0L) {
    return(invisible(NULL))
  }
  check_package("arrow", "saving data slots as Feather files")

  factor_info <- lapply(df, function(col) {
    if (is.factor(col)) {
      list(levels = levels(col), ordered = is.ordered(col))
    } else {
      NULL
    }
  })
  saveRDS(
    factor_info,
    file = file.path(tmp, paste0(slot_name, "_factor_info.rds")),
    compress = FALSE
  )

  df_out <- df
  df_out[] <- lapply(df_out, function(col) {
    if (is.factor(col)) as.character(col) else col
  })
  arrow::write_feather(
    df_out,
    sink = file.path(tmp, paste0(slot_name, ".feather"))
  )
}

#' @keywords internal
load_data_slot <- function(slot_name, tmp) {
  feather_path <- file.path(tmp, paste0(slot_name, ".feather"))
  if (!file.exists(feather_path)) {
    return(NULL)
  }

  check_package("arrow", "loading data slots from Feather files")
  df <- arrow::read_feather(feather_path)

  factor_path <- file.path(tmp, paste0(slot_name, "_factor_info.rds"))
  if (file.exists(factor_path)) {
    factor_info <- readRDS(factor_path)
    for (col_name in names(factor_info)) {
      info <- factor_info[[col_name]]
      if (!is.null(info)) {
        df[[col_name]] <- factor(
          df[[col_name]],
          levels = info$levels,
          ordered = info$ordered
        )
      }
    }
  }
  df
}

#' @keywords internal
check_package <- function(pkg, context) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg {pkg}} is required for {context}.",
      i = "Install with {.run install.packages('{pkg}')}"
    ))
  }
}


# =============================================================================
# one_way.modelblueprint
# =============================================================================

#' One-way analysis for a modelblueprint
#'
#' Calls [one_way()] using the modelblueprint's target, exposure, and data
#' slots. Optionally overlays the model's in-sample predictions to produce
#' a lift chart (pass `predictions = TRUE`).
#'
#' @param data        A `modelblueprint`.
#' @param var         `[character(1)]` Feature to plot on the x-axis.
#' @param set         `[character(1)]` Which dataset to use: `"train"`,
#'                    `"test"`, or `"holdout"`. Default `"train"`.
#' @param predictions `[logical(1)]` If `TRUE`, adds in-sample model
#'                    predictions as a second line (lift chart mode).
#'                    Default `FALSE`.
#' @param split       `[character(1) | NA]` Optional split variable.
#' @param bins        `[integer(1)]` Number of bins. Default `35L`.
#' @param type_agg    `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @param ret         `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.
#' @param ...         Further arguments passed to [one_way()].
#' @param precomputed_preds `[numeric | NULL]` Optional vector of pre-computed
#'   predictions (one per row of the requested `set`). Only used when
#'   `predictions = TRUE`. When supplied, the internal
#'   `predict.modelblueprint()` call is skipped.
#' @return A plotly object or data.table depending on `ret`.
#' @method one_way modelblueprint
#' @export
one_way.modelblueprint <- function(
  data,
  var = NA,
  set = c("train", "test", "holdout"),
  predictions = FALSE,
  split = NA_character_,
  bins = 35L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...,
  precomputed_preds = NULL
) {
  set <- match.arg(set)
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  df <- prop(data, set)
  if (is.null(df)) {
    cli::cli_abort(
      "modelblueprint {.arg @{set}} is NULL. Supply data when constructing."
    )
  }

  # Align obs scale with predictions — if feat_eng_fun transforms the response,
  # update the obs column in df so obs and predictions are on the same scale.
  df_eng <- as.data.frame(data@feat_eng_fun(data@pre_process_fun(as.data.frame(
    df
  ))))
  if (data@y_name %in% names(df_eng)) {
    df <- as.data.frame(df)
    df[[data@y_name]] <- df_eng[[data@y_name]]
  }

  resolved <- resolve_obs(data, df, predictions, precomputed_preds = precomputed_preds)
  obs <- resolved$obs
  df <- resolved$df
  exposure <- resolve_exposure(data, df)

  # Resolve variables: NA means all columns except:
  #   - obs columns (target + prediction overlay when predictions = TRUE)
  #   - the exposure column
  #   - expo_name from the MB slot (handles edge cases where the column name
  #     differs from what resolve_exposure returns)
  vars <- if (length(var) == 1L && is.na(var)) {
    exclude <- unique(c(
      obs,
      if (exposure %in% names(df)) exposure else NULL,
      if (!is.na(data@expo_name) && data@expo_name %in% names(df))
        data@expo_name else NULL
    ))
    setdiff(names(df), exclude)
  } else {
    var
  }

  dots <- list(...)
  dots[["var"]] <- NULL

  run_one_way <- function(v) {
    do.call(
      one_way,
      c(
        list(
          data = df,
          var = v,
          obs = obs,
          exposure = exposure,
          split = split,
          bins = bins,
          type_agg = type_agg,
          ret = ret
        ),
        dots
      )
    )
  }

  if (length(vars) == 1L) {
    run_one_way(vars)
  } else {
    stats::setNames(lapply(vars, run_one_way), vars)
  }
}


# =============================================================================
# pdp.modelblueprint
# =============================================================================

#' Partial dependence plot for a modelblueprint
#'
#' Calls [pdp()] using the modelblueprint's model, target, exposure, and
#' data slots.
#'
#' @param data        A `modelblueprint`.
#' @param var         `[character(1)]` Feature to compute the PDP for.
#' @param set         `[character(1)]` Dataset to use: `"train"`, `"test"`,
#'                    or `"holdout"`. Default `"train"`.
#' @param bins        `[integer(1)]` Number of bins. Default `10L`.
#' @param sample_size `[integer(1)]` Rows to sample. Default `10000L`.
#' @param type_agg    `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @param ret         `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.
#' @param ...         Further arguments passed to [pdp()].
#' @return A plotly object or data.table depending on `ret`.
#' @method pdp modelblueprint
#' @export
pdp.modelblueprint <- function(
  data,
  var = NA,
  set = c("train", "test", "holdout"),
  bins = 10L,
  sample_size = 10000L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
) {
  set <- match.arg(set)
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  df <- prop(data, set)
  if (is.null(df)) {
    cli::cli_abort(
      "modelblueprint {.arg @{set}} is NULL. Supply data when constructing."
    )
  }

  if (is.na(data@y_name)) {
    cli::cli_abort(
      "{.arg @y_name} is not set. Specify the target variable name."
    )
  }

  exposure <- resolve_exposure(data, df)
  model_name <- data@model_display_name %||% "model"

  # Resolve variables: NA means "all x_original_inputs"
  vars <- if (length(var) == 1L && is.na(var)) {
    x <- data@x_original_inputs
    if (length(x) == 0L) {
      cli::cli_abort(
        "{.arg var} = NA requires {.arg @x_original_inputs} to be set on the modelblueprint."
      )
    }
    x
  } else {
    var
  }

  # Drop `var` from ... so it cannot conflict with the explicit var = v below.
  dots <- list(...)
  dots[["var"]] <- NULL

  run_pdp <- function(v) {
    do.call(
      pdp,
      c(
        list(
          data = df,
          var = v,
          obs = data@y_name,
          model = data@model,
          exposure = exposure,
          bins = bins,
          sample_size = sample_size,
          type_agg = type_agg,
          model_name = model_name,
          ret = ret,
          pre_process_fun = data@pre_process_fun,
          feat_eng_fun = data@feat_eng_fun,
          post_process_fun = data@post_process_fun
        ),
        dots
      )
    )
  }

  if (length(vars) == 1L) {
    run_pdp(vars)
  } else {
    stats::setNames(lapply(vars, run_pdp), vars)
  }
}


# =============================================================================
# shap.modelblueprint
# =============================================================================

#' SHAP plots for a modelblueprint
#'
#' Calls [shap()] using the modelblueprint's model, data, and pipeline slots.
#'
#' @param data        A `modelblueprint`.
#' @param vars        `[character]` Features to compute SHAP for. Defaults to
#'                    `data@x_original_inputs` when `NA`.
#' @param set         `[character(1)]` Which dataset to use: `"train"`
#'                    (default), `"test"`, or `"holdout"`.
#' @param type        `[character(1)]` `"importance"` (default) or
#'                    `"dependence"`. See [shap()] for details.
#' @param nsim        `[integer(1)]` Monte Carlo permutations per row.
#'                    Default `50L`.
#' @param sample_size `[integer(1)]` Rows sampled for SHAP computation.
#'                    Default `500L`.
#' @param bins        `[integer(1)]` Number of bins for the dependence plot
#'                    x-axis. Default `10L`.
#' @param type_agg    `[character(1)]` Binning strategy: `"equal_exposure"`
#'                    (default) or `"equal_range"`.
#' @param ret         `[character(1)]` `"plot"` (default) or `"data"`.
#' @param ...         Further arguments passed to [shap()].
#'
#' @return A plotly object, a named list of plotly objects, or a data.table
#'   depending on `type` and `ret`.
#'
#' @method shap modelblueprint
#' @export
shap.modelblueprint <- function(
  data,
  vars        = NA,
  set         = c("train", "test", "holdout"),
  type        = c("importance", "dependence"),
  nsim        = 50L,
  sample_size = 500L,
  bins        = 10L,
  type_agg    = c("equal_exposure", "equal_range"),
  ret         = c("plot", "data"),
  ...
) {
  set      <- match.arg(set)
  type     <- match.arg(type)
  type_agg <- match.arg(type_agg)
  ret      <- match.arg(ret)

  df <- prop(data, set)
  if (is.null(df)) {
    cli::cli_abort(
      "modelblueprint {.arg @{set}} is NULL. Supply data when constructing."
    )
  }

  vars_resolved <- if (length(vars) == 1L && is.na(vars)) {
    x <- stats::na.omit(data@x_original_inputs)
    if (length(x) == 0L) {
      cli::cli_abort(
        "{.arg vars} = NA requires {.arg @x_original_inputs} to be set on the modelblueprint."
      )
    }
    x
  } else {
    vars
  }

  model_name <- data@model_display_name %||% "model"
  exposure   <- resolve_exposure(data, df)

  shap(
    data             = as.data.frame(df),
    model            = data@model,
    vars             = vars_resolved,
    exposure         = exposure,
    type             = type,
    nsim             = nsim,
    sample_size      = sample_size,
    bins             = bins,
    type_agg         = type_agg,
    ret              = ret,
    model_name       = model_name,
    pre_process_fun  = data@pre_process_fun,
    feat_eng_fun     = data@feat_eng_fun,
    post_process_fun = data@post_process_fun,
    ...
  )
}


# =============================================================================
# Internal helpers
# =============================================================================

#' @keywords internal
#' @noRd
resolve_obs <- function(object, df, predictions, precomputed_preds = NULL) {
  y <- object@y_name
  if (is.na(y)) {
    cli::cli_abort(
      "{.arg @y_name} is not set. Specify the target variable name."
    )
  }
  if (!predictions) {
    return(list(obs = y, df = df))
  }

  pred_col <- paste0(".pred_", object@model_display_name %||% "model")
  if (!is.null(precomputed_preds)) {
    df[[pred_col]] <- precomputed_preds
  } else {
    df[[pred_col]] <- predict.modelblueprint(object, df)
  }
  list(obs = c(y, pred_col), df = df)
}

#' @keywords internal
#' @noRd
resolve_exposure <- function(object, df) {
  expo <- object@expo_name
  if (!is.na(expo) && nzchar(expo) && expo %in% names(df)) {
    expo
  } else {
    "vec_of_ones"
  }
}


# =============================================================================
# .onLoad — register S3 methods for the S7 package-qualified class name
# =============================================================================
# S7 stores the class as "modelblueprint::modelblueprint". UseMethod() needs
# methods registered under that exact string. registerS3method() at load time
# is the correct approach — it avoids backtick-named functions that R CMD check
# flags as apparent unregistered methods.
.onLoad <- function(libname, pkgname) {
  ns <- asNamespace(pkgname)
  registerS3method(
    "predict",
    "modelblueprint::modelblueprint",
    predict.modelblueprint,
    envir = ns
  )
  registerS3method(
    "filter",
    "modelblueprint::modelblueprint",
    filter.modelblueprint,
    envir = ns
  )
  registerS3method(
    "mutate",
    "modelblueprint::modelblueprint",
    mutate.modelblueprint,
    envir = ns
  )
  registerS3method(
    "left_join",
    "modelblueprint::modelblueprint",
    left_join.modelblueprint,
    envir = ns
  )
  registerS3method(
    "one_way",
    "modelblueprint::modelblueprint",
    one_way.modelblueprint,
    envir = ns
  )
  registerS3method(
    "pdp",
    "modelblueprint::modelblueprint",
    pdp.modelblueprint,
    envir = ns
  )
  registerS3method(
    "gain",
    "modelblueprint::modelblueprint",
    gain.modelblueprint,
    envir = ns
  )
  registerS3method(
    "pred_vs_obs",
    "modelblueprint::modelblueprint",
    pred_vs_obs.modelblueprint,
    envir = ns
  )
  registerS3method(
    "residuals_grouped",
    "modelblueprint::modelblueprint",
    residuals_grouped.modelblueprint,
    envir = ns
  )
  registerS3method("sami", "list", sami.list, envir = ns)
  registerS3method(
    "gain",
    "modelblueprint::modelblueprint",
    gain.modelblueprint,
    envir = ns
  )
  registerS3method(
    "shap",
    "modelblueprint::modelblueprint",
    shap.modelblueprint,
    envir = ns
  )
  registerS3method("predict", "mb_seq", predict.mb_seq, envir = ns)
  registerS3method(
    "predict",
    "modelblueprint::mb_seq",
    predict.mb_seq,
    envir = ns
  )
}


# =============================================================================
# Utilities
# =============================================================================

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
}
