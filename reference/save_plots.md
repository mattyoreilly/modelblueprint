# Save plots or HTML widgets to a single HTML file

Saves a plotly/htmlwidget object, a list of them, or an HTML tag list to
an HTML file. The output can optionally be made self-contained by
embedding all dependencies inline with Pandoc.

## Usage

``` r
save_plots(plots, file, selfcontained = TRUE, libdir = NULL)
```

## Arguments

- plots:

  What to save. One of:

  - a single `htmlwidget` (e.g. a `plotly` object) or HTML tag,

  - a list of `htmlwidget` objects / tags,

  - an existing `shiny.tag.list`.

  A single object is wrapped into a length-1 list; anything that is not
  already a `shiny.tag.list` is coerced via
  [`htmltools::tagList()`](https://rstudio.github.io/htmltools/reference/tagList.html).

- file:

  `[character(1)]` Path to the output HTML file.

- selfcontained:

  `[logical(1)]` Embed all dependencies into a single self-contained
  file? Requires Pandoc. Default `TRUE`.

- libdir:

  `[character(1) | NULL]` Directory for the HTML dependency files,
  resolved relative to `file`'s directory (or absolute). When `NULL`,
  defaults to `"<file basename>_files"` next to `file`. Pass the same
  value (e.g. `"lib"`) for several files saved into one directory to
  share a single dependency folder between them. Removed after embedding
  when `selfcontained = TRUE`.

## Value

The path to the generated HTML file, invisibly.

## Examples

``` r
if (FALSE) { # interactive()
p1 <- plotly::plot_ly(mtcars, x = ~mpg, y = ~wt)
p2 <- plotly::plot_ly(mtcars, x = ~mpg, y = ~hp)

# a single widget ...
save_plots(p1, tempfile(fileext = ".html"), selfcontained = FALSE)
# ... or a list of them
save_plots(list(p1, p2), tempfile(fileext = ".html"), selfcontained = FALSE)
}
```
