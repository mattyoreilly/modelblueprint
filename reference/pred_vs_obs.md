# Predicted vs Observed Calibration Plot

Creates a Hosmer-style calibration chart showing average predicted
values against average observed values across bins of the prediction
space. A yellow exposure bar on the secondary axis shows the
distribution of data.

## Usage

``` r
pred_vs_obs(data, ...)

# Default S3 method
pred_vs_obs(
  data,
  pred = "predict",
  obs = "observed",
  exposure = "exposure",
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  title = "",
  ret = c("plot", "data"),
  ...
)

# S3 method for class 'modelblueprint'
pred_vs_obs(
  data,
  set = c("train", "test", "holdout"),
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  title = NULL,
  ret = c("plot", "data"),
  ...,
  precomputed_preds = NULL
)
```

## Arguments

- data:

  A `modelblueprint` object.

- ...:

  Passed to `pred_vs_obs.default()`.

- pred:

  `[character(1)]` Name of the predictions column.

- obs:

  `[character(1)]` Name of the observed target column.

- exposure:

  `[character(1)]` Name of the exposure column. If the column is absent,
  every row is given weight 1. Default `"exposure"`.

- bins:

  `[integer(1)]` Number of bins. Default `10L`.

- type_agg:

  `[character(1)]` `"equal_exposure"` or `"equal_range"`.

- title:

  `[character(1)]` Chart title. Defaults to `model_display_name` (with
  the set name appended when plotting multiple sets).

- ret:

  `[character(1)]` `"plot"` or `"data"`. Default `"plot"`.

- set:

  `[character]` Dataset splits to use: any of `"train"`, `"test"`,
  `"holdout"`. Defaults to all available (non-NULL) sets. When more than
  one set is used, a named list with one result per set is returned.

- precomputed_preds:

  `[numeric | NULL]` Optional vector of pre-computed predictions (one
  per row of the requested `set`). When supplied, the internal
  [`predict.modelblueprint()`](https://mattyoreilly.github.io/modelblueprint/reference/predict.ModelBlueprint.md)
  call is skipped.

## Value

A plotly object or data.table depending on `ret`.

A plotly object or data.table depending on `ret`.

## Examples

``` r
# \donttest{
mb <- modelblueprint(
  model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train  = mtcars,
  y_name = "vs",
  model_display_name = "logistic_vs"
)
pred_vs_obs(mb)

{"x":{"visdat":{"1b9523c9fb21":["function () ","plotlyVisDat"]},"cur_data":"1b9523c9fb21","attrs":{"1b9523c9fb21":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[1,2,3,4,5,6,7,8,9,10],"y":[4,3,3,3,3,3,3,3,3,4],"type":"bar","name":"Exposure","marker":{"color":"#ffff00"},"yaxis":"y2","inherit":true},"1b9523c9fb21.1":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[1,2,3,4,5,6,7,8,9,10],"y":[0,0,0,0,0.33333333333333331,0.66666666666666663,0.66666666666666663,0.66666666666666663,1,1],"type":"scatter","mode":"markers","name":"Observed","marker":{"size":7,"color":"rgb(0,0,128)","symbol":"circle"},"yaxis":"y","inherit":true},"1b9523c9fb21.2":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[1,2,3,4,5,6,7,8,9,10],"y":[3.0119505840138254e-05,0.0043837060015286169,0.012875001192762971,0.020699811223330845,0.19604826944796525,0.61245868138860982,0.73320758636404104,0.84934117191774783,0.92322388618405105,0.98579129564592183],"type":"scatter","mode":"lines","name":"Predicted","line":{"color":"rgb(0,0,0)","width":2,"dash":"dash"},"yaxis":"y","inherit":true}},"layout":{"margin":{"b":120,"l":50,"t":25,"r":80},"title":"logistic_vs","xaxis":{"domain":[0,1],"automargin":true,"title":"Predicted (binned)","tickangle":-45,"tickmode":"array","tickvals":[1,2,3,4,5,6,7,8,9,10],"ticktext":["(2.2749e-08, 0.000163326]","(0.000163326, 0.00813611]","(0.00813611, 0.0157828]","(0.0157828, 0.0649784]","(0.0649784, 0.459202]","(0.459202, 0.689082]","(0.689082, 0.815987]","(0.815987, 0.869412]","(0.869412, 0.976281]","(0.976281, 0.995129]"]},"yaxis":{"domain":[0,1],"automargin":true,"title":"Observed / Predicted rate","overlaying":"y2","showgrid":false},"yaxis2":{"title":"Exposure","side":"right","showgrid":false},"legend":{"x":1.1000000000000001,"y":0.5},"barmode":"overlay","hovermode":"closest","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[1,2,3,4,5,6,7,8,9,10],"y":[4,3,3,3,3,3,3,3,3,4],"type":"bar","name":"Exposure","marker":{"color":"#ffff00","line":{"color":"rgba(31,119,180,1)"}},"yaxis":"y2","error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","frame":null},{"x":[1,2,3,4,5,6,7,8,9,10],"y":[0,0,0,0,0.33333333333333331,0.66666666666666663,0.66666666666666663,0.66666666666666663,1,1],"type":"scatter","mode":"markers","name":"Observed","marker":{"color":"rgb(0,0,128)","size":7,"symbol":"circle","line":{"color":"rgba(255,127,14,1)"}},"yaxis":"y","error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"line":{"color":"rgba(255,127,14,1)"},"xaxis":"x","frame":null},{"x":[1,2,3,4,5,6,7,8,9,10],"y":[3.0119505840138254e-05,0.0043837060015286169,0.012875001192762971,0.020699811223330845,0.19604826944796525,0.61245868138860982,0.73320758636404104,0.84934117191774783,0.92322388618405105,0.98579129564592183],"type":"scatter","mode":"lines","name":"Predicted","line":{"color":"rgb(0,0,0)","width":2,"dash":"dash"},"yaxis":"y","marker":{"color":"rgba(44,160,44,1)","line":{"color":"rgba(44,160,44,1)"}},"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"xaxis":"x","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}# }
```
