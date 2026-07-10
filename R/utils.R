# =============================================================================
# Utilities
# =============================================================================

# `%||%` (NULL coalescing) is imported from rlang — see ModelBlueprint-package.R.
# This companion handles the common pattern of optional S7 character properties
# that use NA_character_ as their "not set" sentinel rather than NULL.
`%|NA|%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && (is.na(a) || !nzchar(a)))) b else a
}

#' unitise a numeric variable to the range 0 to 1
#'
#' Caps a variable at `min_val` and `max_val` then scales it between 0 and 1.
#' Returns a modified copy — the caller's data is never mutated.
#'
#' @param data    A `data.frame` or `data.table`.
#' @param var     `[character(1)]` Name of the column to unitise.
#' @param min_val `[numeric(1)]` Lower cap. Values below this are set to 0.
#' @param max_val `[numeric(1)]` Upper cap. Values above this are set to 1.
#'
#' @return A copy of `data` with `var` scaled 0 to 1.
#' @export
unitise <- function(data, var, min_val, max_val) {
  if (!is.data.frame(data) && !inherits(data, "data.table")) {
    cli::cli_abort("{.arg data} must be a data.frame or data.table.")
  }
  if (!var %in% names(data)) {
    cli::cli_abort("{.arg var} column {.val {var}} not found in {.arg data}.")
  }
  if (
    !is.numeric(min_val) ||
      length(min_val) != 1L ||
      !is.numeric(max_val) ||
      length(max_val) != 1L
  ) {
    cli::cli_abort(
      "{.arg min_val} and {.arg max_val} must be single numeric values."
    )
  }
  if (min_val >= max_val) {
    cli::cli_abort("{.arg min_val} must be less than {.arg max_val}.")
  }

  # Work on a copy — never mutate caller data
  out <- data.table::copy(data.table::as.data.table(data))
  x <- as.numeric(out[[var]])
  out[[var]] <- (pmin(pmax(x, min_val), max_val) - min_val) /
    (max_val - min_val)

  if (is.data.frame(data) && !inherits(data, "data.table")) {
    out <- as.data.frame(out)
  }
  out
}

#' Save plots or HTML widgets to a single HTML file
#'
#' Saves a plotly/htmlwidget object, a list of them, or an HTML tag list to an
#' HTML file. The output can optionally be made self-contained by embedding all
#' dependencies inline with Pandoc.
#'
#' @param plots What to save. One of:
#'   * a single `htmlwidget` (e.g. a `plotly` object) or HTML tag,
#'   * a list of `htmlwidget` objects / tags,
#'   * an existing `shiny.tag.list`.
#'
#'   A single object is wrapped into a length-1 list; anything that is not
#'   already a `shiny.tag.list` is coerced via [htmltools::tagList()].
#' @param file `[character(1)]` Path to the output HTML file.
#' @param selfcontained `[logical(1)]` Embed all dependencies into a single
#'   self-contained file? Requires Pandoc. Default `TRUE`.
#' @param libdir `[character(1) | NULL]` Directory for the HTML dependency
#'   files, resolved relative to `file`'s directory (or absolute). When
#'   `NULL`, defaults to `"<file basename>_files"` next to `file`. Pass the
#'   same value (e.g. `"lib"`) for several files saved into one directory to
#'   share a single dependency folder between them. Removed after embedding
#'   when `selfcontained = TRUE`.
#'
#' @return The path to the generated HTML file, invisibly.
#'
#' @examplesIf interactive()
#' p1 <- plotly::plot_ly(mtcars, x = ~mpg, y = ~wt)
#' p2 <- plotly::plot_ly(mtcars, x = ~mpg, y = ~hp)
#'
#' # a single widget ...
#' save_plots(p1, tempfile(fileext = ".html"), selfcontained = FALSE)
#' # ... or a list of them
#' save_plots(list(p1, p2), tempfile(fileext = ".html"), selfcontained = FALSE)
#'
#' @export
save_plots <- function(plots, file, selfcontained = TRUE, libdir = NULL) {
  if (!is.character(file) || length(file) != 1L || is.na(file)) {
    cli::cli_abort("{.arg file} must be a single file path.")
  }
  check_package("htmltools", "saving plots to HTML")

  # Accept a single widget/tag, a list of them, or an existing tag list.
  # A single widget *is* a list internally, so it must be wrapped before
  # tagList() rather than iterated over.
  if (!inherits(plots, "shiny.tag.list")) {
    if (inherits(plots, c("htmlwidget", "shiny.tag"))) {
      plots <- list(plots)
    }
    if (!is.list(plots) || length(plots) == 0L) {
      cli::cli_abort(
        "{.arg plots} must be an htmlwidget/tag, or a non-empty list of them."
      )
    }
    is_ok <- vapply(
      plots,
      function(p) inherits(p, c("htmlwidget", "shiny.tag", "shiny.tag.list")),
      logical(1L)
    )
    if (!all(is_ok)) {
      cli::cli_abort(c(
        "Every element of {.arg plots} must be an htmlwidget or HTML tag.",
        x = "Element{?s} {.val {which(!is_ok)}} {?is/are} not."
      ))
    }
    plots <- htmltools::tagList(plots)
  }

  # htmltools::save_html() resolves a relative libdir against `file`'s
  # directory (it setwd()s there before copying), so pass a bare folder name.
  # A libdir that repeats the file's directory prefix gets created *inside*
  # that directory a second time, and the resulting hrefs break as soon as
  # the output is moved — rendering every plot blank.
  if (is.null(libdir)) {
    libdir <- paste0(tools::file_path_sans_ext(basename(file)), "_files")
  }

  htmltools::save_html(plots, file = file, libdir = libdir)

  if (selfcontained) {
    check_package("rmarkdown", "creating a self-contained HTML file")
    if (!rmarkdown::pandoc_available()) {
      cli::cli_abort(c(
        "Saving a self-contained HTML file requires Pandoc.",
        i = "Install Pandoc from {.url https://pandoc.org/installing.html}.",
        i = "Or set {.code selfcontained = FALSE} to skip embedding."
      ))
    }
    pandoc_self_contained(file)
    lib_path <- if (grepl("^(/|~|[A-Za-z]:)", libdir)) {
      libdir
    } else {
      file.path(dirname(file), libdir)
    }
    unlink(lib_path, recursive = TRUE)
  }

  invisible(file)
}

#' Embed a HTML file's external dependencies inline via Pandoc
#'
#' Replaces the htmlwidgets internal `pandoc_self_contained_html()` (avoids a
#' `:::` call) using the same underlying Pandoc invocation through the exported
#' [rmarkdown::pandoc_convert()]. Pandoc cannot read and write the same file in
#' one pass, so the embedded output is written to a temp file and copied back.
#'
#' @param file `[character(1)]` HTML file to rewrite in place.
#' @keywords internal
#' @noRd
pandoc_self_contained <- function(file) {
  # `--self-contained` was deprecated in Pandoc 2.19 in favour of
  # `--embed-resources --standalone`; pick whichever the available Pandoc has.
  opts <- if (rmarkdown::pandoc_available("2.19")) {
    c("--standalone", "--embed-resources")
  } else {
    "--self-contained"
  }
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)
  rmarkdown::pandoc_convert(
    input   = normalizePath(file, mustWork = TRUE),
    to      = "html",
    output  = tmp,
    options = opts
  )
  file.copy(tmp, file, overwrite = TRUE)
  invisible(file)
}
