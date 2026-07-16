#' @keywords internal
"_PACKAGE"

# Central import declarations — keep all @importFrom tags here rather than
# scattered across individual function files. Run `devtools::document()` after
# any change to regenerate NAMESPACE.

# Selective imports — prefer @importFrom over whole-package @import to avoid
# masking collisions (e.g. data.table and dplyr both export `:=`, `first`,
# `last`, `between`) and to keep the NAMESPACE minimal. plotly, RColorBrewer
# and most data.table functions are called fully-qualified (plotly::, etc.),
# so only the symbols genuinely needed in-scope are imported below:
#   - S7: the class-system verbs used throughout the package.
#   - data.table: the non-standard-evaluation pronouns (`:=`, `.SD`, `.N`)
#     that cannot be namespace-qualified inside `dt[...]`.
#   - rlang `%||%`: the NULL-coalescing operator. (The pipe is the native `|>`.)
#' @importFrom S7 new_class new_property new_generic new_union
#' @importFrom S7 class_any class_character class_numeric class_function
#' @importFrom S7 class_list class_data.frame
#' @importFrom S7 prop prop<- props method method<-
#' @importFrom S7 S7_dispatch S7_inherits
# S7 only exports `@` on R < 4.3 (base R handles S7 `@` natively from 4.3).
# Without this conditional import, `@` inside package code resolves to base's
# S4 slot operator on older R and every property access errors with
# "trying to get slot from an object that is not an S4 object".
#' @rawNamespace if (getRversion() < "4.3.0") importFrom("S7", "@")
#' @importFrom data.table := .SD .N
#' @importFrom RColorBrewer brewer.pal
#' @importFrom rlang %||%
#' @importFrom dplyr filter mutate left_join
#' @importFrom stats var sd predict median
#' @importFrom stats quantile binomial gaussian poisson
#' @importFrom stats rnorm runif rgamma

# Shared S7 union types used across multiple files.
# Defined here so they are available regardless of file load order.
class_tabular <- new_union(NULL, class_data.frame)

NULL

# Re-export the dplyr generics that modelblueprint defines methods for, so
# `library(modelblueprint)` alone is enough to call filter()/mutate()/
# left_join() on a blueprint — without also attaching dplyr.

#' @importFrom dplyr filter
#' @export
dplyr::filter

#' @importFrom dplyr mutate
#' @export
dplyr::mutate

#' @importFrom dplyr left_join
#' @export
dplyr::left_join
