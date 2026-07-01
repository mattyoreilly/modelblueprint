# Cumulative Gains Chart

Plots cumulative gains curves for one or more competing scores against a
perfect model baseline. The Gini coefficient for each score is shown in
the legend.

## Usage

``` r
gain(data, ...)

# S3 method for class 'modelblueprint'
gain(
  data,
  set = c("train", "test", "holdout"),
  title = NULL,
  ret = c("plot", "data", "gini"),
  ...,
  precomputed_preds = NULL
)
```

## Arguments

- data:

  A `modelblueprint` object.

- ...:

  Passed to the default method.

- set:

  Which dataset to use: `"train"`, `"test"`, or `"holdout"`.

- title:

  Chart title. Defaults to `model_display_name`.

- ret:

  `"plot"`, `"data"`, or `"gini"`. Default `"plot"`.

- precomputed_preds:

  `[numeric | NULL]` Optional vector of pre-computed predictions (one
  per row of the requested `set`). When supplied, the internal
  [`predict.modelblueprint()`](https://mattyoreilly.github.io/modelblueprint/reference/predict.ModelBlueprint.md)
  call is skipped. Use this in loops or dashboards where predictions
  have already been computed to avoid redundant scoring.

## Value

A plotly object, list of data.tables, or list of Gini values.

## Examples

``` r
# \donttest{
mb <- modelblueprint(
  model  = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train  = mtcars,
  y_name = "vs",
  model_display_name = "logistic_vs"
)
gain(mb)

{"x":{"visdat":{"1b4f1116ebfb":["function () ","plotlyVisDat"]},"cur_data":"1b4f1116ebfb","attrs":{"1b4f1116ebfb":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"y":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"type":"scatter","mode":"lines","name":"Mean model, Gini: 0.000","line":{"color":"rgb(180,180,180)","dash":"dot","width":1},"inherit":true},"1b4f1116ebfb.1":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"y":[0.071428571428571425,0.14285714285714285,0.21428571428571427,0.2857142857142857,0.35714285714285715,0.42857142857142855,0.5,0.5714285714285714,0.6428571428571429,0.7142857142857143,0.7857142857142857,0.8571428571428571,0.9285714285714286,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],"type":"scatter","mode":"lines","name":"Perfect model, Gini: 0.560","line":{"color":"rgb(0,0,0)","dash":"dash","width":1},"inherit":true},"1b4f1116ebfb.2":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"y":[0.071428571428571425,0.14285714285714285,0.21428571428571427,0.2857142857142857,0.35714285714285715,0.42857142857142855,0.5,0.5714285714285714,0.5714285714285714,0.6428571428571429,0.7142857142857143,0.7142857142857143,0.7857142857142857,0.7857142857142857,0.8571428571428571,0.9285714285714286,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],"type":"scatter","mode":"lines","name":".pred_logistic_vs, Gini: 0.502","line":{"color":"rgb(237,41,57)"},"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"title":"logistic_vs","xaxis":{"domain":[0,1],"automargin":true,"title":"Cumulative % of Exposure","rangemode":"tozero"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Cumulative % of Target","rangemode":"tozero","showgrid":false},"legend":{"x":1.05,"y":0.5},"hovermode":"closest","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"y":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"type":"scatter","mode":"lines","name":"Mean model, Gini: 0.000","line":{"color":"rgb(180,180,180)","dash":"dot","width":1},"marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"y":[0.071428571428571425,0.14285714285714285,0.21428571428571427,0.2857142857142857,0.35714285714285715,0.42857142857142855,0.5,0.5714285714285714,0.6428571428571429,0.7142857142857143,0.7857142857142857,0.8571428571428571,0.9285714285714286,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],"type":"scatter","mode":"lines","name":"Perfect model, Gini: 0.560","line":{"color":"rgb(0,0,0)","dash":"dash","width":1},"marker":{"color":"rgba(255,127,14,1)","line":{"color":"rgba(255,127,14,1)"}},"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[0.03125,0.0625,0.09375,0.125,0.15625,0.1875,0.21875,0.25,0.28125,0.3125,0.34375,0.375,0.40625,0.4375,0.46875,0.5,0.53125,0.5625,0.59375,0.625,0.65625,0.6875,0.71875,0.75,0.78125,0.8125,0.84375,0.875,0.90625,0.9375,0.96875,1],"y":[0.071428571428571425,0.14285714285714285,0.21428571428571427,0.2857142857142857,0.35714285714285715,0.42857142857142855,0.5,0.5714285714285714,0.5714285714285714,0.6428571428571429,0.7142857142857143,0.7142857142857143,0.7857142857142857,0.7857142857142857,0.8571428571428571,0.9285714285714286,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],"type":"scatter","mode":"lines","name":".pred_logistic_vs, Gini: 0.502","line":{"color":"rgb(237,41,57)"},"marker":{"color":"rgba(44,160,44,1)","line":{"color":"rgba(44,160,44,1)"}},"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"xaxis":"x","yaxis":"y","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}# }
```
