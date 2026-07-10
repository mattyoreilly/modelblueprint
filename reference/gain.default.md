# Cumulative Gains Chart (default method)

Cumulative Gains Chart (default method)

## Usage

``` r
# Default S3 method
gain(
  data,
  pred = "predict",
  obs = NA_character_,
  exposure = "exposure",
  title = "Cumulative Gains",
  ret = c("plot", "data", "gini"),
  ...
)
```

## Arguments

- data:

  A `data.frame` or `data.table`.

- pred:

  `[character]` Name(s) of competing score columns.

- obs:

  `[character(1)]` Name of the target variable column.

- exposure:

  `[character(1)]` Name of the exposure column. Default `"exposure"`.

- title:

  `[character(1)]` Chart title.

- ret:

  `"plot"`, `"data"`, or `"gini"`. Default `"plot"`.

- ...:

  Unused.

## Value

A plotly object, list of data.tables, or list of Gini values.

## Examples

``` r
# \donttest{
df <- data.frame(
  obs      = c(0, 1, 0, 1, 1),
  pred     = c(0.1, 0.9, 0.2, 0.8, 0.7),
  exposure = rep(1, 5)
)
gain(df, pred = "pred", obs = "obs", exposure = "exposure")

{"x":{"visdat":{"1c8f7501bd25":["function () ","plotlyVisDat"]},"cur_data":"1c8f7501bd25","attrs":{"1c8f7501bd25":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"y":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"type":"scatter","mode":"lines","name":"Mean model, Gini: 0.000","line":{"color":"rgb(180,180,180)","dash":"dot","width":1},"inherit":true},"1c8f7501bd25.1":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"y":[0.33333333333333331,0.66666666666666663,1,1,1],"type":"scatter","mode":"lines","name":"Perfect model, Gini: 0.333","line":{"color":"rgb(0,0,0)","dash":"dash","width":1},"inherit":true},"1c8f7501bd25.2":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"y":[0.33333333333333331,0.66666666666666663,1,1,1],"type":"scatter","mode":"lines","name":"pred, Gini: 0.333","line":{"color":"rgb(237,41,57)"},"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"title":"Cumulative Gains","xaxis":{"domain":[0,1],"automargin":true,"title":"Cumulative % of Exposure","rangemode":"tozero"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Cumulative % of Target","rangemode":"tozero","showgrid":false},"legend":{"x":1.05,"y":0.5},"hovermode":"closest","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"y":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"type":"scatter","mode":"lines","name":"Mean model, Gini: 0.000","line":{"color":"rgb(180,180,180)","dash":"dot","width":1},"marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"y":[0.33333333333333331,0.66666666666666663,1,1,1],"type":"scatter","mode":"lines","name":"Perfect model, Gini: 0.333","line":{"color":"rgb(0,0,0)","dash":"dash","width":1},"marker":{"color":"rgba(255,127,14,1)","line":{"color":"rgba(255,127,14,1)"}},"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[0.20000000000000001,0.40000000000000002,0.59999999999999998,0.80000000000000004,1],"y":[0.33333333333333331,0.66666666666666663,1,1,1],"type":"scatter","mode":"lines","name":"pred, Gini: 0.333","line":{"color":"rgb(237,41,57)"},"marker":{"color":"rgba(44,160,44,1)","line":{"color":"rgba(44,160,44,1)"}},"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"xaxis":"x","yaxis":"y","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}# }
```
