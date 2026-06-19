# Call a user-supplied pipeline function with a helpful error on missing pkg

Intercepts "could not find function" errors that arise when a pipeline
function (pre_process_fun, feat_eng_fun, post_process_fun) was written
with unqualified calls (e.g. `as.data.table()` instead of
[`data.table::as.data.table()`](https://rdrr.io/pkg/data.table/man/as.data.table.html))
and the required package is not loaded in the current session.

## Usage

``` r
call_pipeline_fun(fun, fun_name, ...)
```

## Arguments

- fun:

  The pipeline function to call.

- fun_name:

  Character label used in the error message.

- ...:

  Arguments forwarded to `fun`.
