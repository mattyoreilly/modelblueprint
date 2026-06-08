# =============================================================================
# Utilities
# =============================================================================

# Null coalescing — returns b when a is NA or NULL
`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
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
