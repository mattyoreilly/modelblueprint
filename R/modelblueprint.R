# =============================================================================
# ModelBlueprint.R
# S7 class for managing the full lifecycle of a machine learning model.
# =============================================================================

NULL

# Union type: NULL | data.frame (covers tibble) — defined before new_class()
class_tabular <- new_union(NULL, class_data.frame)

# =============================================================================
# ModelBlueprint S7 class
# =============================================================================

#' ModelBlueprint: a model-agnostic container for ML model lifecycles
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
#' mb <- ModelBlueprint(
#'   model  = lm(mpg ~ wt + hp, data = mtcars),
#'   train  = mtcars,
#'   y_name = "mpg"
#' )
#' predict(mb, mtcars)
#' }
#'
#' @usage NULL
#' @export
ModelBlueprint <- new_class(
  name = "ModelBlueprint",

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

#' Generate predictions from a ModelBlueprint
#'
#' Applies `pre_process_fun` -> `feat_eng_fun` -> model prediction ->
#' `post_process_fun` to `newdata`.
#'
#' @param object  A `ModelBlueprint`.
#' @param newdata A `data.frame` or `data.table`.
#' @param ...     Unused.
#' @return A numeric vector of predictions.
#' @export
predict.ModelBlueprint <- function(object, newdata, ...) {
  if (missing(newdata) || is.null(newdata)) {
    stop("`newdata` is required for prediction.", call. = FALSE)
  }
  if (!is.data.frame(newdata) && !inherits(newdata, "data.table")) {
    stop("`newdata` must be a data.frame or data.table.", call. = FALSE)
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

#' @keywords internal
#' @noRd
method(print, ModelBlueprint) <- function(x, ...) {
  rule <- function(ch = "-", n = 60L) paste(rep(ch, n), collapse = "")
  cat(rule("="), "\n")
  cat("ModelBlueprint\n")
  cat(rule("="), "\n")
  cat(sprintf("  Model:        %s\n", paste(class(x@model), collapse = "/")))
  cat(sprintf("  Display name: %s\n", x@model_display_name %||% "<not set>"))
  cat(sprintf("  Target:       %s\n", x@y_name %||% "<not set>"))
  cat(sprintf("  Exposure:     %s (val = %s)\n", x@expo_name, x@expo_val))
  cat(sprintf(
    "  Features:     %d original / %d engineered\n",
    length(na.omit(x@x_original_inputs)),
    length(na.omit(x@x_names))
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
  invisible(x)
}

format_nrow <- function(d) {
  if (is.null(d)) "<not set>" else format(nrow(d), big.mark = ",")
}


# =============================================================================
# dplyr-style methods
# =============================================================================

#' Filter rows in a ModelBlueprint's datasets
#' @param .data A `ModelBlueprint`.
#' @param ... Filter expressions passed to `dplyr::filter()`.
#' @param sets Which datasets to filter. Default: all non-NULL.
#' @return A new `ModelBlueprint`.
#' @method filter ModelBlueprint
#' @export
filter.ModelBlueprint <- function(
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

#' Mutate columns in a ModelBlueprint's datasets
#' @param .data A `ModelBlueprint`.
#' @param ... Expressions passed to `dplyr::mutate()`.
#' @param sets Which datasets to mutate. Default: all non-NULL.
#' @return A new `ModelBlueprint`.
#' @method mutate ModelBlueprint
#' @export
mutate.ModelBlueprint <- function(
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

#' Left-join into a ModelBlueprint's datasets
#' @param x A `ModelBlueprint`.
#' @param y A `data.frame` to join.
#' @param by Join keys.
#' @param sets Which datasets to join. Default: all non-NULL.
#' @param ... Passed to `dplyr::left_join()`.
#' @return A new `ModelBlueprint`.
#' @method left_join ModelBlueprint
#' @export
left_join.ModelBlueprint <- function(
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

#' Save a ModelBlueprint to disk
#'
#' Serialises a `ModelBlueprint` to a compressed `.tar.gz` archive containing
#' all components needed to fully reconstruct it: model, data splits, pipeline
#' functions, and metadata.
#'
#' @param object   A `ModelBlueprint` object.
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

method(saveMB, ModelBlueprint) <- function(
  object,
  path = getwd(),
  filename = NULL
) {
  if (is.null(filename)) {
    filename <- prop(object, "model_display_name")
    if (is.na(filename) || !nzchar(filename)) {
      stop(
        "`filename` must be supplied when `model_display_name` is not set.",
        call. = FALSE
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
  # ModelBlueprint and any future subclass (ModelBlueprintSequence etc.)
  saveRDS(
    list(
      class = class(object),
      version = utils::packageVersion("ModelBlueprint")
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
  message(sprintf("ModelBlueprint saved: %s", normalizePath(final_path)))
  invisible(normalizePath(final_path))
}


# =============================================================================
# loadMB
# =============================================================================

#' Load a ModelBlueprint from disk
#'
#' Reconstructs a `ModelBlueprint` from a `.tar.gz` archive created by [saveMB()].
#'
#' @param path Path to the `.tar.gz` archive created by [saveMB()].
#' @return A fully reconstructed `ModelBlueprint` object.
#' @seealso [saveMB()]
#' @export
loadMB <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Archive not found: %s", path), call. = FALSE)
  }

  tmp <- file.path(tempdir(), paste0("loadMB_", as.integer(Sys.time())))
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::untar(path, exdir = tmp)

  meta_path <- file.path(tmp, "meta.rds")
  if (!file.exists(meta_path)) {
    message("Note: archive has no metadata; assuming ModelBlueprint class.")
    return(load_modelblueprint(tmp))
  }

  meta <- readRDS(meta_path)

  # Add a new branch here when ModelBlueprintSequence is introduced.
  # S7 stores the class as "ModelBlueprint::ModelBlueprint" (package-qualified).
  # Strip the package prefix before switching so both bare and qualified names work.
  bare_class <- sub("^.*::", "", meta$class[[1L]])

  switch(
    bare_class,
    ModelBlueprint = load_modelblueprint(tmp),
    stop(
      sprintf(
        "Don't know how to load class '%s'. Is the right package version installed?",
        bare_class
      ),
      call. = FALSE
    )
  )
}


# =============================================================================
# Internal helpers
# =============================================================================

#' @keywords internal
save_model_slot <- function(model, tmp) {
  is_h2o <- inherits(
    model,
    c(
      "H2OModel",
      "H2OBinomialModel",
      "H2ORegressionModel",
      "H2OMultinomialModel",
      "H2OAutoML"
    )
  )
  if (is_h2o) {
    check_package("h2o", "saving H2O models")
    h2o::h2o.saveModel(model, path = tmp, filename = "h2o_binary", force = TRUE)
    tryCatch(
      h2o::h2o.save_mojo(
        model,
        path = tmp,
        filename = "h2o_mojo",
        force = TRUE
      ),
      error = function(e) {
        message(
          "Note: MOJO export failed (model type may not support MOJO): ",
          conditionMessage(e)
        )
      }
    )
  }
  # Always save the R-side object — needed for class detection on load
  saveRDS(model, file = file.path(tmp, "r_model.rds"), compress = FALSE)
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

  do.call(ModelBlueprint, args)
}

#' @keywords internal
load_model_slot <- function(tmp) {
  r_model_path <- file.path(tmp, "r_model.rds")
  if (!file.exists(r_model_path)) {
    stop("Archive is missing the model file (r_model.rds).", call. = FALSE)
  }
  r_model <- readRDS(r_model_path)

  is_h2o <- inherits(
    r_model,
    c(
      "H2OModel",
      "H2OBinomialModel",
      "H2ORegressionModel",
      "H2OMultinomialModel",
      "H2OAutoML"
    )
  )
  if (!is_h2o) {
    return(r_model)
  }

  check_package("h2o", "loading H2O models")
  # Suppress the version-age warning from h2o.clusterInfo() inside h2o.init().
  # Try the default port first; fall back to an alternate port in case the JVM
  # is still shutting down from a previous session and 54321 is in a broken state.
  tryCatch(
    suppressWarnings(suppressMessages(h2o::h2o.init(
      port = 54321L,
      startH2O = TRUE
    ))),
    error = function(e) {
      tryCatch(
        suppressWarnings(suppressMessages(h2o::h2o.init(
          port = 54399L,
          startH2O = TRUE
        ))),
        error = function(e2) {
          stop(
            "Could not start an H2O cluster to load the model: ",
            conditionMessage(e2),
            call. = FALSE
          )
        }
      )
    }
  )
  h2o::h2o.loadModel(path = file.path(tmp, "h2o_binary"))
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
    stop(
      sprintf(
        "Package '%s' is required for %s.\nInstall it with: install.packages(\"%s\")",
        pkg,
        context,
        pkg
      ),
      call. = FALSE
    )
  }
}


# =============================================================================
# one_way.ModelBlueprint
# =============================================================================

#' One-way analysis for a ModelBlueprint
#'
#' Calls [one_way()] using the ModelBlueprint's target, exposure, and data
#' slots. Optionally overlays the model's in-sample predictions to produce
#' a lift chart (pass `predictions = TRUE`).
#'
#' @param data        A `ModelBlueprint`.
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
#' @return A plotly object or data.table depending on `ret`.
#' @method one_way ModelBlueprint
#' @export
one_way.ModelBlueprint <- function(
  data,
  var,
  set = c("train", "test", "holdout"),
  predictions = FALSE,
  split = NA_character_,
  bins = 35L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  ...
) {
  set <- match.arg(set)
  type_agg <- match.arg(type_agg)
  ret <- match.arg(ret)

  df <- prop(data, set)
  if (is.null(df)) {
    stop(
      sprintf(
        "ModelBlueprint `@%s` is NULL. Supply data when constructing the object.",
        set
      ),
      call. = FALSE
    )
  }

  obs <- resolve_obs(data, df, set, predictions)
  exposure <- resolve_exposure(data, df)

  one_way(
    data = df,
    var = var,
    obs = obs,
    exposure = exposure,
    split = split,
    bins = bins,
    type_agg = type_agg,
    ret = ret,
    ...
  )
}


# =============================================================================
# pdp.ModelBlueprint
# =============================================================================

#' Partial dependence plot for a ModelBlueprint
#'
#' Calls [pdp()] using the ModelBlueprint's model, target, exposure, and
#' data slots.
#'
#' @param data        A `ModelBlueprint`.
#' @param var         `[character(1)]` Feature to compute the PDP for.
#' @param set         `[character(1)]` Dataset to use: `"train"`, `"test"`,
#'                    or `"holdout"`. Default `"train"`.
#' @param bins        `[integer(1)]` Number of bins. Default `10L`.
#' @param sample_size `[integer(1)]` Rows to sample. Default `10000L`.
#' @param type_agg    `[character(1)]` `"equal_exposure"` or `"equal_range"`.
#' @param ret         `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.
#' @param ...         Further arguments passed to [pdp()].
#' @return A plotly object or data.table depending on `ret`.
#' @method pdp ModelBlueprint
#' @export
pdp.ModelBlueprint <- function(
  data,
  var,
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
    stop(
      sprintf(
        "ModelBlueprint `@%s` is NULL. Supply data when constructing the object.",
        set
      ),
      call. = FALSE
    )
  }

  if (is.na(data@y_name)) {
    stop(
      "ModelBlueprint `@y_name` is not set. Specify the target variable name.",
      call. = FALSE
    )
  }

  exposure <- resolve_exposure(data, df)
  model_name <- if (!is.na(data@model_display_name)) {
    data@model_display_name
  } else {
    "model"
  }

  pdp(
    data = df,
    var = var,
    obs = data@y_name,
    model = data@model,
    exposure = exposure,
    bins = bins,
    sample_size = sample_size,
    type_agg = type_agg,
    model_name = model_name,
    ret = ret,
    ...
  )
}

# =============================================================================
# Internal helpers
# =============================================================================

#' @keywords internal
#' @noRd
resolve_obs <- function(object, df, set, predictions) {
  y <- object@y_name
  if (is.na(y)) {
    stop(
      "ModelBlueprint `@y_name` is not set. Specify the target variable name.",
      call. = FALSE
    )
  }
  if (!predictions) {
    return(y)
  }

  pred_col <- paste0(".pred_", object@model_display_name %||% "model")
  df[[pred_col]] <- predict.ModelBlueprint(object, df)
  assign("df", df, envir = parent.frame())
  c(y, pred_col)
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
# S7 stores the class as "ModelBlueprint::ModelBlueprint". UseMethod() needs
# methods registered under that exact string. registerS3method() at load time
# is the correct approach — it avoids backtick-named functions that R CMD check
# flags as apparent unregistered methods.
.onLoad <- function(libname, pkgname) {
  ns <- asNamespace(pkgname)
  registerS3method(
    "predict",
    "ModelBlueprint::ModelBlueprint",
    predict.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "filter",
    "ModelBlueprint::ModelBlueprint",
    filter.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "mutate",
    "ModelBlueprint::ModelBlueprint",
    mutate.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "left_join",
    "ModelBlueprint::ModelBlueprint",
    left_join.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "one_way",
    "ModelBlueprint::ModelBlueprint",
    one_way.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "pdp",
    "ModelBlueprint::ModelBlueprint",
    pdp.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "gain",
    "ModelBlueprint::ModelBlueprint",
    gain.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "pred_vs_obs",
    "ModelBlueprint::ModelBlueprint",
    pred_vs_obs.ModelBlueprint,
    envir = ns
  )
  registerS3method(
    "residuals_grouped",
    "ModelBlueprint::ModelBlueprint",
    residuals_grouped.ModelBlueprint,
    envir = ns
  )
  registerS3method("sami", "list", sami.list, envir = ns)
  registerS3method(
    "gain",
    "ModelBlueprint::ModelBlueprint",
    gain.ModelBlueprint,
    envir = ns
  )
}


# =============================================================================
# Utilities
# =============================================================================

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
}
