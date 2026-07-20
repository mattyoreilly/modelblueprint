# Plot the distribution of the target variable

Bins the target variable and plots the total exposure per bin as a bar
chart — an exposure-weighted distribution of the target. Shares its
argument conventions, binning, NA handling, split behaviour, and plotly
styling with
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md);
the only difference is that the target itself is the x-axis variable, so
there is no `obs` argument.

## Usage

``` r
distribution(data, ...)

# Default S3 method
distribution(
  data,
  var = "target",
  exposure = "exposure",
  split = NA_character_,
  bins = 35L,
  time_unit = NA_character_,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  verbose = FALSE,
  ...
)
```

## Arguments

- data:

  A data frame or data.table. Must contain all columns referenced by
  other arguments.

- ...:

  Arguments passed to methods.

- var:

  Target column whose distribution to plot. Bare name or string. Default
  `"target"`.

- exposure:

  Column of exposure weights. If the column does not exist in `data`,
  every row is given weight 1. Bare name or string. Default
  `"exposure"`.

- split:

  Optional column to group bars by. Bare name, string, or `NA` / `NULL`
  for no split. Default `NA`.

- bins:

  `[integer(1)]` Number of equal-exposure bins for numeric targets with
  more than `bins` unique values. Default 35.

- time_unit:

  `[character(1)]` For Date / POSIXct targets, the width of each bin
  (passed to
  [`base::cut.POSIXt()`](https://rdrr.io/r/base/cut.POSIXt.html)).
  Default `NA`.

- type_agg:

  `[character(1)]` Binning strategy for numeric targets:
  `"equal_exposure"` (default) or `"equal_range"`.

- ret:

  `[character(1)]` `"plot"` (default) returns a plotly object; `"data"`
  returns the aggregated data.table.

- verbose:

  `[logical(1)]` Report how many NA values of `var` were moved to the
  trailing `"NA"` category? Default `FALSE`.

## Value

A plotly object, or a data.table when `ret = "data"`, or `NULL` with a
warning if the plot cannot be produced.

## Details

Column name arguments (`var`, `exposure`, `split`) accept both bare
(unquoted) names and strings, so `distribution(df, mpg)` and
`distribution(df, "mpg")` are equivalent.

## Examples

``` r
# \donttest{
distribution(mtcars, mpg, bins = 10)

{"x":{"visdat":{"1bbd103b5077":["function () ","plotlyVisDat"]},"cur_data":"1bbd103b5077","attrs":{"1bbd103b5077":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00"},"hoverinfo":"text","hovertext":["Exposure: [10.4,13.3] = 3.000000 (9.4%)","Exposure: (13.3,15] = 3.000000 (9.4%)","Exposure: (15,15.5] = 3.000000 (9.4%)","Exposure: (15.5,17.3] = 3.000000 (9.4%)","Exposure: (17.3,19.2] = 5.000000 (15.6%)","Exposure: (19.2,21] = 3.000000 (9.4%)","Exposure: (21,21.4] = 2.000000 (6.2%)","Exposure: (21.4,22.8] = 3.000000 (9.4%)","Exposure: (22.8,27.3] = 3.000000 (9.4%)","Exposure: (27.3,33.9] = 4.000000 (12.5%)"],"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"xaxis":{"domain":[0,1],"automargin":true,"title":"mpg","categoryorder":"array","categoryarray":["[10.4,13.3]","(13.3,15]","(15,15.5]","(15.5,17.3]","(17.3,19.2]","(19.2,21]","(21,21.4]","(21.4,22.8]","(22.8,27.3]","(27.3,33.9]"],"type":"category"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Exposure","showgrid":true,"autorange":true},"legend":{"x":1.1499999999999999,"y":0.5},"hovermode":"x","plot_bgcolor":"rgba(0,0,0,0)","paper_bgcolor":"rgba(0,0,0,0)","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":["[10.4,13.3]","(13.3,15]","(15,15.5]","(15.5,17.3]","(17.3,19.2]","(19.2,21]","(21,21.4]","(21.4,22.8]","(22.8,27.3]","(27.3,33.9]"],"y":[3,3,3,3,5,3,2,3,3,4],"type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00","line":{"color":"rgba(31,119,180,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Exposure: [10.4,13.3] = 3.000000 (9.4%)","Exposure: (13.3,15] = 3.000000 (9.4%)","Exposure: (15,15.5] = 3.000000 (9.4%)","Exposure: (15.5,17.3] = 3.000000 (9.4%)","Exposure: (17.3,19.2] = 5.000000 (15.6%)","Exposure: (19.2,21] = 3.000000 (9.4%)","Exposure: (21,21.4] = 2.000000 (6.2%)","Exposure: (21.4,22.8] = 3.000000 (9.4%)","Exposure: (22.8,27.3] = 3.000000 (9.4%)","Exposure: (27.3,33.9] = 4.000000 (12.5%)"],"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","yaxis":"y","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}distribution(mtcars, var = "mpg", split = "am")

{"x":{"visdat":{"1bbd561473e8":["function () ","plotlyVisDat"],"1bbd4bfa80e4":["function () ","data"],"1bbd5db43296":["function () ","data"]},"cur_data":"1bbd5db43296","attrs":{"1bbd4bfa80e4":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"type":"bar","orientation":"v","name":0,"marker":{"color":"#A6CEE3"},"hoverinfo":"text","hovertext":["Exposure (0): 2.000000 (10.5% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 2.000000 (10.5% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 2.000000 (10.5% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)"],"inherit":true},"1bbd5db43296":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"type":"bar","orientation":"v","name":1,"marker":{"color":"#1F78B4"},"hoverinfo":"text","hovertext":["Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 2.000000 (15.4% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 2.000000 (15.4% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)"],"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"barmode":"group","xaxis":{"domain":[0,1],"automargin":true,"title":"mpg","categoryorder":"array","categoryarray":["10.4","13.3","14.3","14.7","15","15.2","15.5","15.8","16.4","17.3","17.8","18.1","18.7","19.2","19.7","21","21.4","21.5","22.8","24.4","26","27.3","30.4","32.4","33.9"],"type":"category"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Exposure","showgrid":true,"autorange":true},"legend":{"x":1.1499999999999999,"y":0.5,"title":{"text":"<b>am<\/b>"}},"hovermode":"x","plot_bgcolor":"rgba(0,0,0,0)","paper_bgcolor":"rgba(0,0,0,0)","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":["10.4","13.3","14.3","14.7","15.2","15.5","16.4","17.3","17.8","18.1","18.7","19.2","21.4","21.5","22.8","24.4"],"y":[2,1,1,1,2,1,1,1,1,1,1,2,1,1,1,1],"type":"bar","orientation":"v","name":0,"marker":{"color":"#A6CEE3","line":{"color":"rgba(31,119,180,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text"],"hovertext":["Exposure (0): 2.000000 (10.5% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 2.000000 (10.5% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 2.000000 (10.5% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)","Exposure (0): 1.000000 (5.3% of 0)"],"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":["15","15.8","19.7","21","21.4","22.8","26","27.3","30.4","32.4","33.9"],"y":[1,1,1,2,1,1,1,1,2,1,1],"type":"bar","orientation":"v","name":1,"marker":{"color":"#1F78B4","line":{"color":"rgba(255,127,14,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text","text"],"hovertext":["Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 2.000000 (15.4% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 2.000000 (15.4% of 1)","Exposure (1): 1.000000 (7.7% of 1)","Exposure (1): 1.000000 (7.7% of 1)"],"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"xaxis":"x","yaxis":"y","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}# }
```
