# Resolve a captured column argument to a column name string

String -\> itself; bare name that is a column of `data` -\> that name;
anything else forces the `fallback` promise (default string, local
variable, or complex expression).

## Usage

``` r
resolve_bare_name(expr, data, fallback)
```
