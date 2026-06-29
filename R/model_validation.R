# =============================================================================
# model_validation.R
# Generate and save a structured set of validation plots for a modelblueprint.
# =============================================================================


#' Generate and save model validation plots
#'
#' Runs a configurable set of diagnostic and feature-analysis plots for each
#' requested dataset split and writes the results to structured HTML files
#' inside a directory named after `@model_display_name`.
#'
#' @param mb               A `modelblueprint` object.
#' @param sets             `[character]` Dataset splits to process.
#'   Default `c("train", "test", "holdout")`. NULL splits are silently skipped.
#' @param plots            `[character]` Plot types to produce. Any combination
#'   of `"validation"`, `"oneway"`, `"pdp"`, `"stability"`, `"shap"`.
#' @param validation_bins  `[integer(1)]` Bins for gain / pred-vs-obs charts.
#'   Default `10L`.
#' @param one_way_bins     `[integer(1)]` Bins for one-way charts.
#'   Default `10L`.
#' @param pdp_bins         `[integer(1)]` Bins for PDP charts. Default `10L`.
#' @param split            `[character(1)]` Column name to segment one-way
#'   plots by. `NA` (default) produces unsplit charts.
#' @param selfcontained    `[logical(1)]` Passed to [save_plots()]. `TRUE`
#'   (default) embeds all dependencies into each HTML file. Set to `FALSE`
#'   for faster saves during development.
#' @param filepath         `[character(1)]` Parent directory for all output.
#'   Defaults to `getwd()`. A subdirectory named `@model_display_name` is
#'   created inside.
#'
#' @return The root output directory path, invisibly.
#'
#' @details
#' **Output layout**
#'
#' ```
#' <filepath>/
#'   <model_display_name>/
#'     <name>.tar.gz
#'     validation/
#'       <name>_<set>_validation_plots.html
#'     oneway/
#'       <name>_<set>_oneway_plots.html
#'       <name>_<set>_stability_plots.html   # if "stability" requested
#'     pdp/
#'       <name>_<set>_pdp_plots.html
#'     shap/
#'       <name>_<set>_shap_plots.html
#' ```
#'
#' **Validation** plots include a gain chart, predicted-vs-observed calibration
#' chart, and grouped residuals — one HTML file per split.
#'
#' **One-way** plots cover every feature in `@x_original_inputs`. If `split`
#' is supplied the column is passed to [one_way()]; otherwise charts are
#' unsplit.
#'
#' **Stability** plots are one-way charts split by a random 50/50 variable
#' (`"A"` / `"B"`). If the two lines overlap closely the patterns are stable
#' and not driven by random noise.
#'
#' **PDP** plots cover every feature in `@x_original_inputs`.
#'
#' **SHAP** plots use [shap()] with `type = "importance"`. The modelblueprint
#' must have `@x_original_inputs` set and the model must support kernel SHAP.
#'
#' The modelblueprint itself is serialised via [savemb()] into the root
#' output directory.
#'
#' @seealso [gain()], [pred_vs_obs()], [residuals_grouped()], [one_way()],
#'   [pdp()], [shap()], [save_plots()], [savemb()]
#'
#' @export
model_validation <- function(
  mb,
  sets            = c("train", "test", "holdout"),
  plots           = c("validation", "oneway", "pdp", "stability", "shap"),
  validation_bins = 10L,
  one_way_bins    = 10L,
  pdp_bins        = 10L,
  split           = NA_character_,
  filepath        = getwd(),
  selfcontained   = TRUE
) {

  # ── input validation ────────────────────────────────────────────────────────
  if (!S7::S7_inherits(mb, modelblueprint)) {
    cli::cli_abort("{.arg mb} must be a {.cls modelblueprint} object.")
  }

  plots <- match.arg(
    plots,
    c("validation", "oneway", "pdp", "stability", "shap"),
    several.ok = TRUE
  )
  sets <- match.arg(sets, c("train", "test", "holdout"), several.ok = TRUE)

  display_name <- mb@model_display_name
  if (is.na(display_name) || !nzchar(display_name)) {
    cli::cli_abort(
      "{.arg mb} must have {.field @model_display_name} set to use {.fn model_validation}."
    )
  }

  features <- stats::na.omit(mb@x_original_inputs)
  if (length(features) == 0L) {
    cli::cli_abort(
      "{.arg mb} must have {.field @x_original_inputs} set to use {.fn model_validation}."
    )
  }

  # ── directory setup ─────────────────────────────────────────────────────────
  root_dir <- file.path(filepath, display_name)
  dir.create(root_dir, recursive = TRUE, showWarnings = FALSE)

  if ("validation" %in% plots) {
    dir.create(file.path(root_dir, "validation"), showWarnings = FALSE)
  }
  if (any(c("oneway", "stability") %in% plots)) {
    dir.create(file.path(root_dir, "oneway"), showWarnings = FALSE)
  }
  if ("pdp" %in% plots) {
    dir.create(file.path(root_dir, "pdp"), showWarnings = FALSE)
  }
  if ("shap" %in% plots) {
    dir.create(file.path(root_dir, "shap"), showWarnings = FALSE)
  }

  # ── helpers ─────────────────────────────────────────────────────────────────
  obs_col  <- mb@y_name
  expo_col <- mb@expo_name
  expo_arg <- if (!is.na(expo_col) && nzchar(expo_col)) expo_col else NULL

  .html_path <- function(subdir, suffix) {
    file.path(
      root_dir, subdir,
      paste0(display_name, "_", set, "_", suffix, ".html")
    )
  }

  .try_plot <- function(expr, label) {
    tryCatch(expr, error = function(e) {
      cli::cli_warn("{label} failed: {conditionMessage(e)}")
      NULL
    })
  }

  # ── per-set loop ─────────────────────────────────────────────────────────────
  for (set in sets) {
    set_data <- prop(mb, set)
    if (is.null(set_data)) {
      cli::cli_warn("Skipping {.val {set}}: slot is NULL.")
      next
    }

    cli::cli_inform("  Processing {.val {set}} ...")

    # ── VALIDATION ────────────────────────────────────────────────────────────
    if ("validation" %in% plots) {
      val_plots <- Filter(Negate(is.null), list(
        gain         = .try_plot(
          gain(mb, set = set, bins = validation_bins),
          paste0("gain(", set, ")")
        ),
        pred_vs_obs  = .try_plot(
          pred_vs_obs(mb, set = set, bins = validation_bins),
          paste0("pred_vs_obs(", set, ")")
        ),
        residuals    = .try_plot(
          residuals_grouped(mb, set = set),
          paste0("residuals_grouped(", set, ")")
        )
      ))

      if (length(val_plots) > 0L) {
        save_plots(val_plots, .html_path("validation", "validation_plots"),
                   selfcontained = selfcontained)
      }
    }

    # ── ONE-WAY ───────────────────────────────────────────────────────────────
    if ("oneway" %in% plots) {
      ow_split_arg <- if (!is.na(split) && nzchar(split)) split else NULL

      ow_plots <- Filter(Negate(is.null), lapply(
        stats::setNames(features, features),
        function(feat) {
          .try_plot(
            one_way(mb, var = feat, set = set, bins = one_way_bins,
                    predictions = TRUE, split = ow_split_arg),
            paste0("one_way(", feat, ", ", set, ")")
          )
        }
      ))

      if (length(ow_plots) > 0L) {
        save_plots(ow_plots, .html_path("oneway", "oneway_plots"),
                   selfcontained = selfcontained)
      }
    }

    # ── STABILITY ─────────────────────────────────────────────────────────────
    if ("stability" %in% plots) {
      rand_col            <- ".rand_split"
      stab_data           <- set_data
      stab_data[[rand_col]] <- sample(c("A", "B"), nrow(stab_data),
                                      replace = TRUE)

      stab_plots <- Filter(Negate(is.null), lapply(
        stats::setNames(features, features),
        function(feat) {
          .try_plot(
            one_way(
              stab_data,
              var      = feat,
              obs      = obs_col,
              exposure = expo_arg,
              bins     = one_way_bins,
              split    = rand_col
            ),
            paste0("stability one_way(", feat, ", ", set, ")")
          )
        }
      ))

      if (length(stab_plots) > 0L) {
        save_plots(stab_plots, .html_path("oneway", "stability_plots"),
                   selfcontained = selfcontained)
      }
    }

    # ── PDP ───────────────────────────────────────────────────────────────────
    if ("pdp" %in% plots) {
      pdp_plots <- Filter(Negate(is.null), lapply(
        stats::setNames(features, features),
        function(feat) {
          .try_plot(
            pdp(mb, var = feat, set = set, bins = pdp_bins),
            paste0("pdp(", feat, ", ", set, ")")
          )
        }
      ))

      if (length(pdp_plots) > 0L) {
        save_plots(pdp_plots, .html_path("pdp", "pdp_plots"),
                   selfcontained = selfcontained)
      }
    }

    # ── SHAP ──────────────────────────────────────────────────────────────────
    if ("shap" %in% plots) {
      shap_result <- .try_plot(
        shap(mb, set = set, type = "importance", ret = "plot"),
        paste0("shap(", set, ")")
      )

      if (!is.null(shap_result)) {
        shap_plots <- if (is.list(shap_result) && !inherits(shap_result, "htmlwidget")) {
          shap_result
        } else {
          list(shap = shap_result)
        }
        save_plots(shap_plots, .html_path("shap", "shap_plots"),
                   selfcontained = selfcontained)
      }
    }
  }

  # ── save modelblueprint ──────────────────────────────────────────────────────
  savemb(mb, path = root_dir, filename = display_name)

  cli::cli_inform(c("v" = "Saved to {.path {root_dir}}"))
  invisible(root_dir)
}
