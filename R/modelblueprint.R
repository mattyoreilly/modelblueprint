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
#' @details
#' # Construction
#'
#' Create a blueprint by passing a fitted model plus, optionally, its data
#' splits and metadata:
#'
#' ```r
#' modelblueprint(
#'   model,
#'   train = NULL, test = NULL, holdout = NULL,
#'   pre_process_fun  = function(df) df,
#'   feat_eng_fun     = function(df) df,
#'   post_process_fun = function(preds, df_raw) preds,
#'   x_original_inputs = NA_character_, x_names = NA_character_,
#'   y_name = NA_character_, yhat_name = NA_character_,
#'   expo_name = "exposure", expo_val = 1, expo_0_rep = 0.1,
#'   offset_name = NA_character_, offset_value = NA_real_,
#'   model_display_name = NA_character_, deploy_notes = NA_character_
#' )
#' ```
#'
#' Only `model` is required; every other property has a sensible default. See
#' the argument list and the example below for details.
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
#' # Wrap a fitted model together with its training data and metadata.
#' mb <- modelblueprint(
#'   model              = lm(mpg ~ wt + hp, data = mtcars),
#'   train              = mtcars,
#'   y_name             = "mpg",
#'   x_original_inputs  = c("wt", "hp"),
#'   model_display_name = "lm_mpg"
#' )
#'
#' mb                       # print method shows a structured summary
#' predict(mb, head(mtcars))
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
    errors <- character()
    note <- function(msg) errors <<- c(errors, msg)

    # ── Scalar string properties ─────────────────────────────────────────────
    # S7 enforces class_character, but not length-1 or non-empty content.
    # Empty strings are almost always typos; NA_character_ is the right sentinel.
    check_str <- function(val, nm) {
      if (length(val) != 1L) {
        note(sprintf("@%s must be a single string (got length %d).", nm, length(val)))
      } else if (!is.na(val) && !nzchar(val)) {
        note(sprintf(
          "@%s cannot be an empty string. Use NA_character_ to leave it unset.", nm
        ))
      }
    }
    check_str(self@y_name,             "y_name")
    check_str(self@yhat_name,          "yhat_name")
    check_str(self@expo_name,          "expo_name")
    check_str(self@offset_name,        "offset_name")
    check_str(self@model_display_name, "model_display_name")
    check_str(self@deploy_notes,       "deploy_notes")

    # ── Positive finite numerics ─────────────────────────────────────────────
    check_pos <- function(val, nm) {
      if (length(val) != 1L) {
        note(sprintf("@%s must be a single positive finite number (got length %d).", nm, length(val)))
      } else if (!is.finite(val) || val <= 0) {
        note(sprintf("@%s must be a single positive finite number (got %s).", nm, val))
      }
    }
    check_pos(self@expo_val,   "expo_val")
    check_pos(self@expo_0_rep, "expo_0_rep")

    # ── offset_value: scalar, finite when not NA ─────────────────────────────
    if (length(self@offset_value) != 1L) {
      note("@offset_value must be a single number or NA.")
    } else if (!is.na(self@offset_value) && !is.finite(self@offset_value)) {
      note(sprintf("@offset_value must be finite (got %s).", self@offset_value))
    }

    # ── Cross-property: y_name and yhat_name must differ ────────────────────
    # Guard with length == 1L: non-scalar cases are already caught by check_str
    # above. Without the guard, !is.na() on a length-2 vector produces a
    # length-2 logical and if() throws "length > 1 in coercion to logical(1)".
    y  <- self@y_name
    yh <- self@yhat_name
    if (
      length(y)  == 1L && !is.na(y)  && nzchar(y)  &&
      length(yh) == 1L && !is.na(yh) && nzchar(yh) &&
      identical(y, yh)
    ) {
      note(sprintf(
        "@y_name and @yhat_name are both '%s'. They must refer to different columns.", y
      ))
    }

    # ── x_original_inputs: no empty strings, no duplicates ──────────────────
    x <- self@x_original_inputs[!is.na(self@x_original_inputs)]
    if (length(x) > 0L) {
      if (any(!nzchar(x))) {
        note("@x_original_inputs must not contain empty strings.")
      }
      dupes <- x[duplicated(x)]
      if (length(dupes) > 0L) {
        note(sprintf(
          "@x_original_inputs contains duplicate name(s): %s.",
          paste(unique(dupes), collapse = ", ")
        ))
      }
    }

    # ── Cross-data: column existence in @train ───────────────────────────────
    # expo_name is deliberately NOT checked: resolve_exposure() falls back to
    # unit weights when the column is absent, so a missing expo_name is valid.
    # Same length == 1L guards apply: non-scalar names are caught by check_str.
    if (!is.null(self@train)) {
      cols <- names(self@train)

      if (length(y) == 1L && !is.na(y) && nzchar(y) && !y %in% cols) {
        note(sprintf("@y_name '%s' is not a column in @train.", y))
      }

      missing_x <- setdiff(x, cols)
      if (length(missing_x) > 0L) {
        note(sprintf(
          "@x_original_inputs column(s) not found in @train: %s.",
          paste(missing_x, collapse = ", ")
        ))
      }

      on <- self@offset_name
      if (length(on) == 1L && !is.na(on) && nzchar(on) && !on %in% cols) {
        note(sprintf("@offset_name '%s' is not a column in @train.", on))
      }
    }

    if (length(errors)) paste(errors, collapse = "\n")
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

  tmp <- call_pipeline_fun(object@pre_process_fun, "pre_process_fun", tmp)
  tmp <- call_pipeline_fun(object@feat_eng_fun, "feat_eng_fun", tmp)
  raw_preds <- model_predict(object@model, tmp)
  call_pipeline_fun(
    object@post_process_fun,
    "post_process_fun",
    raw_preds,
    newdata
  )
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
  cat(sprintf("  Display name: %s\n", x@model_display_name %|NA|% "<not set>"))
  cat(sprintf("  Target:       %s\n", x@y_name %|NA|% "<not set>"))
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
# savemb
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
#' @seealso [loadmb()]
#' @export
savemb <- new_generic(
  "savemb",
  "object",
  function(object, path = getwd(), filename = NULL, ...) S7_dispatch()
)

method(savemb, modelblueprint) <- function(
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

  # tempfile() returns a fresh, unique path on every call, so two saves in the
  # same second cannot collide (unlike a Sys.time()-based name).
  tmp <- tempfile("savemb_")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  # Save class metadata so loadmb() can reconstruct the right class.
  # This is what allows loadmb() to be a plain function that works for both
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
  cli::cli_inform(c(v = "modelblueprint saved: {.path {normalizePath(final_path)}}"))
  invisible(normalizePath(final_path))
}


#' @rdname savemb
#' @description
#' `saveMB()` is deprecated; use [savemb()] instead.
#' @export
saveMB <- function(object, path = getwd(), filename = NULL, ...) {
  .Deprecated("savemb", package = "modelblueprint")
  savemb(object, path = path, filename = filename, ...)
}

# mb_seq serialisation is not implemented yet — fail with guidance rather
# than S7's generic "can't find method" error. Defined here (not mb_seq.R)
# because file collation loads mb_seq.R before the savemb generic exists.
method(savemb, new_mb_seq_) <- function(
  object,
  path = getwd(),
  filename = NULL
) {
  cli::cli_abort(c(
    "{.fn savemb} does not support {.cls mb_seq} objects yet.",
    i = "Save each blueprint individually with {.fn savemb} and rebuild the sequence with {.fn mb_seq} + {.fn mb_layer} after loading."
  ))
}


# =============================================================================
# loadmb
# =============================================================================

#' Load a modelblueprint from disk
#'
#' Reconstructs a `modelblueprint` from a `.tar.gz` archive created by [savemb()].
#'
#' @param path Path to the `.tar.gz` archive created by [savemb()].
#' @return A fully reconstructed `modelblueprint` object.
#' @seealso [savemb()]
#' @export
loadmb <- function(path) {
  if (!file.exists(path)) {
    cli::cli_abort("Archive not found: {.path {path}}")
  }

  tmp <- tempfile("loadmb_")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
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


#' @rdname loadmb
#' @description
#' `loadMB()` is deprecated; use [loadmb()] instead.
#' @export
loadMB <- function(path) {
  .Deprecated("loadmb", package = "modelblueprint")
  loadmb(path)
}


# =============================================================================
# Internal helpers
# =============================================================================

#' Call a user-supplied pipeline function with a helpful error on missing pkg
#'
#' Intercepts "could not find function" errors that arise when a pipeline
#' function (pre_process_fun, feat_eng_fun, post_process_fun) was written
#' with unqualified calls (e.g. `as.data.table()` instead of
#' `data.table::as.data.table()`) and the required package is not loaded in
#' the current session.
#'
#' @param fun      The pipeline function to call.
#' @param fun_name Character label used in the error message.
#' @param ...      Arguments forwarded to `fun`.
#' @keywords internal
call_pipeline_fun <- function(fun, fun_name, ...) {
  tryCatch(
    fun(...),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("could not find function", msg, fixed = TRUE)) {
        cli::cli_abort(
          c(
            "{.code {fun_name}} failed: {msg}",
            i = paste0(
              "A package used inside {.code {fun_name}} is not loaded. ",
              "Either call {.code library(<pkg>)} before predicting, or use ",
              "fully-qualified calls in the function ",
              "(e.g. {.code data.table::as.data.table()} instead of ",
              "{.code as.data.table()})."
            )
          ),
          call = NULL
        )
      } else {
        stop(e)
      }
    }
  )
}

# H2O class names — centralised so model_predict (pdp.R) and any future
# H2O-aware code all agree on what counts as an H2O model.
.H2O_CLASSES <- c(
  "H2OModel",
  "H2OBinomialModel",
  "H2OMultinomialModel",
  "H2ORegressionModel",
  "H2OAutoML"
)

#' @keywords internal
is_h2o_model <- function(model) inherits(model, .H2O_CLASSES)


#' @keywords internal
save_model_slot <- function(model, tmp) {
  bundled <- tryCatch(
    bundle::bundle(model),
    error = function(e) {
      cli::cli_warn(c(
        "{.fn bundle::bundle} failed for this model type; falling back to plain {.fn saveRDS}.",
        i = "Predictions may not survive serialisation for models with external C++ state.",
        x = conditionMessage(e)
      ))
      NULL
    }
  )
  saveRDS(
    if (is.null(bundled)) model else bundled,
    file = file.path(tmp, "r_model.rds"),
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
  df_pp <- call_pipeline_fun(
    data@pre_process_fun,
    "pre_process_fun",
    as.data.frame(df)
  )
  df_eng <- as.data.frame(call_pipeline_fun(
    data@feat_eng_fun,
    "feat_eng_fun",
    df_pp
  ))
  df <- as.data.frame(df)
  if (data@y_name %in% names(df_eng)) {
    df[[data@y_name]] <- df_eng[[data@y_name]]
  }

  # Reuse the already-engineered frame to score, rather than letting
  # resolve_obs() call predict.modelblueprint() — which would re-run
  # pre_process_fun + feat_eng_fun a second time over the whole dataset.
  if (isTRUE(predictions) && is.null(precomputed_preds)) {
    raw_preds <- model_predict(data@model, df_eng)
    precomputed_preds <- call_pipeline_fun(
      data@post_process_fun,
      "post_process_fun",
      raw_preds,
      df
    )
  }

  resolved <- resolve_obs(
    data,
    df,
    predictions,
    precomputed_preds = precomputed_preds
  )
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
      if (!is.na(data@expo_name) && data@expo_name %in% names(df)) {
        data@expo_name
      } else {
        NULL
      }
    ))
    setdiff(names(df), exclude)
  } else {
    var
  }

  # Guard: block target and exposure columns from being used as x-axis variables.
  # These are automatically excluded when var = NA; this check covers the case
  # where the caller passes them explicitly.
  if (!(length(var) == 1L && is.na(var))) {
    bad_target   <- intersect(vars, stats::na.omit(data@y_name))
    bad_exposure <- intersect(vars, stats::na.omit(data@expo_name))
    bad <- c(bad_target, bad_exposure)
    if (length(bad) > 0L) {
      detail <- character(0)
      if (length(bad_target) > 0L) {
        detail <- c(
          detail,
          i = "{.val {bad_target}} is the modelblueprint target ({.arg @y_name})."
        )
      }
      if (length(bad_exposure) > 0L) {
        detail <- c(
          detail,
          i = "{.val {bad_exposure}} is the modelblueprint exposure ({.arg @expo_name})."
        )
      }
      cli::cli_abort(c(
        "Cannot plot {.val {bad}} as a one-way variable.",
        detail
      ))
    }

    # Guard: informative error when the requested variable isn't in the dataset.
    missing_vars <- setdiff(vars, names(df))
    if (length(missing_vars) > 0L) {
      cli::cli_abort(c(
        "Variable{?s} not found in the {.val {set}} dataset: {.val {missing_vars}}.",
        i = "Available columns: {.val {sort(names(df))}}"
      ))
    }
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
#'
#' @section Performance:
#' When `@x_original_inputs` is set, the working dataset is narrowed to those
#' columns (plus the target and exposure) before scoring, which avoids copying
#' unused columns on wide frames. This assumes `feat_eng_fun` only consumes the
#' declared `@x_original_inputs`; if your feature engineering reads other
#' columns, leave `@x_original_inputs` unset so the full frame is used.
#'
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
  model_name <- data@model_display_name %|NA|% "model"

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

  # Narrow the working frame to the columns pdp() actually needs before scoring.
  # pdp.default copies every column of the data it is handed, so on a wide frame
  # this avoids duplicating dozens of unused columns. It relies on the contract
  # that feat_eng_fun only consumes the declared @x_original_inputs (plus the
  # target and exposure). When @x_original_inputs is not set we cannot know which
  # columns the pipeline needs, so the full frame is passed through unchanged.
  declared <- as.character(stats::na.omit(data@x_original_inputs))
  if (length(declared) > 0L) {
    keep <- unique(c(
      declared,
      data@y_name,
      if (exposure %in% names(df)) exposure,
      # A model fit with offset(<column>) needs that column at predict time
      # even though it is rarely listed in @x_original_inputs.
      as.character(stats::na.omit(data@offset_name)),
      vars
    ))
    keep <- keep[keep %in% names(df)]
    df <- if (data.table::is.data.table(df)) {
      df[, keep, with = FALSE]
    } else {
      df[keep]
    }
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
  vars = NA,
  set = c("train", "test", "holdout"),
  type = c("importance", "dependence"),
  nsim = 50L,
  sample_size = 500L,
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
) {
  set <- match.arg(set)
  type <- match.arg(type)
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

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

  model_name <- data@model_display_name %|NA|% "model"
  exposure <- resolve_exposure(data, df)

  shap(
    data = as.data.frame(df),
    model = data@model,
    vars = vars_resolved,
    exposure = exposure,
    type = type,
    nsim = nsim,
    sample_size = sample_size,
    bins = bins,
    type_agg = type_agg,
    ret = ret,
    model_name = model_name,
    pre_process_fun = data@pre_process_fun,
    feat_eng_fun = data@feat_eng_fun,
    post_process_fun = data@post_process_fun,
    ...
  )
}


# =============================================================================
# Internal helpers
# =============================================================================

#' Canonical name for a modelblueprint's prediction column
#'
#' Single source of truth for the column name under which in-sample predictions
#' are attached to a dataset. Used by `resolve_obs()` (one_way), `gain()`,
#' `pred_vs_obs()`, and `residuals_grouped()` so that `ret = "data"` output is
#' predictable across every diagnostic: always `.pred_<display_name>`, falling
#' back to `.pred_model` when `@model_display_name` is unset.
#'
#' @keywords internal
#' @noRd
.pred_col_name <- function(object) {
  paste0(".pred_", object@model_display_name %|NA|% "model")
}

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

  pred_col <- .pred_col_name(object)
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

#' Materialise the exposure column for rate-based diagnostics
#'
#' Used by `gain()`, `pred_vs_obs()`, and `residuals_grouped()` — the
#' diagnostics that divide predictions by per-row exposure. Guarantees a
#' usable exposure column: falls back to unit weights when the blueprint's
#' exposure column is absent, and replaces zero exposure values with
#' `@expo_0_rep` so the rate division cannot produce `Inf`.
#'
#' @return A list with `df` (as a data.frame, exposure column materialised)
#'   and `exposure` (the column name to use).
#' @keywords internal
#' @noRd
resolve_exposure_values <- function(object, df) {
  exposure <- resolve_exposure(object, df)
  df <- as.data.frame(df)
  if (exposure == "vec_of_ones") {
    df[[".exposure_ones"]] <- 1L
    exposure <- ".exposure_ones"
  } else {
    zero <- !is.na(df[[exposure]]) & df[[exposure]] == 0
    if (any(zero)) {
      df[[exposure]][zero] <- object@expo_0_rep
      cli::cli_warn(
        "Replaced {sum(zero)} zero-exposure row{?s} with @expo_0_rep = \\
        {object@expo_0_rep} before computing rates."
      )
    }
  }
  list(df = df, exposure = exposure)
}


# =============================================================================
# .onLoad — method registration for the S7 package-qualified class name
# =============================================================================
# Two mechanisms run here, covering the two kinds of method this package defines
# on its S7 classes:
#
# 1. S7::methods_register() — REQUIRED by S7 whenever you define a method() on a
#    generic owned by another package (here: base `print`, and the S7 generic
#    `savemb`). Without it those `method(print, modelblueprint) <- ...`
#    definitions are not wired up in the *installed* package (they only happen
#    to work under pkgload::load_all()). This is the documented S7 pattern; see
#    vignette("compatibility", package = "S7").
#
# 2. registerS3method() — for the package's own S3 generics (one_way(), pdp(),
#    extract_*(), set_*(), …). An S7 object's implicit class is
#    "modelblueprint::modelblueprint", so UseMethod() needs each method
#    registered under that exact string. Registering at load time avoids
#    backtick-named functions that R CMD check flags as apparent unregistered
#    S3 methods.
#
# A regression test (test-dispatch.R) exercises every one of these verbs on a
# real S7 object so a future S7 change cannot silently break dispatch under
# either library() or load_all().
.onLoad <- function(libname, pkgname) {
  S7::methods_register()

  ns <- asNamespace(pkgname)
  registerS3method(
    "print",
    "modelblueprint::modelblueprint",
    print.modelblueprint,
    envir = ns
  )
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
  registerS3method(
    "print",
    "modelblueprint::mb_layer",
    print.mb_layer,
    envir = ns
  )

  # extract_* and set_* verbs (R/extract.R)
  for (.generic in c(
    "extract_fit",
    "extract_train", "extract_test", "extract_holdout",
    "extract_pre_process_fun", "extract_feat_eng_fun", "extract_post_process_fun",
    "extract_original_inputs", "extract_feature_names",
    "extract_target", "extract_yhat_name",
    "extract_exposure_name", "extract_exposure_value", "extract_exposure_zero_rep",
    "extract_offset_name", "extract_offset_value",
    "extract_display_name", "extract_deploy_notes",
    "set_model",
    "set_train", "set_test", "set_holdout",
    "set_pre_process_fun", "set_feat_eng_fun", "set_post_process_fun",
    "set_original_inputs", "set_feature_names",
    "set_target", "set_yhat_name",
    "set_exposure_name", "set_exposure_value", "set_exposure_zero_rep",
    "set_offset_name", "set_offset_value",
    "set_display_name", "set_deploy_notes"
  )) {
    registerS3method(
      .generic,
      "modelblueprint::modelblueprint",
      get(paste0(.generic, ".modelblueprint"), envir = ns),
      envir = ns
    )
  }
  rm(.generic)
}
