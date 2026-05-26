#' @keywords internal
"_PACKAGE"

# Central import declarations — keep all @importFrom tags here rather than
# scattered across individual function files. Run `devtools::document()` after
# any change to regenerate NAMESPACE.

## usethis namespace: start

# Whole-package imports (used pervasively across many files)
#' @import S7
#' @import data.table
#' @import plotly
#' @import RColorBrewer

# Selective imports
#' @importFrom dplyr filter mutate left_join
#' @importFrom grDevices col2rgb
#' @importFrom stats var sd predict median
#' @importFrom stats quantile binomial gaussian poisson

## usethis namespace: end
NULL
