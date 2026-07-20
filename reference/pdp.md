# Partial dependence plot for any predict()-compatible model

For each bin of `var`, the function fixes that feature at the bin
midpoint (numeric) or bin label (categorical), runs
[`predict()`](https://rdrr.io/r/stats/predict.html) across a sample of
the full dataset, and averages the predictions. The result shows the
marginal effect of `var` on model output, stripped of all correlations
with other features.

## Usage

``` r
pdp(data, ...)

# Default S3 method
pdp(
  data,
  var,
  obs,
  model,
  exposure = "exposure",
  bins = 10L,
  sample_size = 10000L,
  type_agg = c("equal_exposure", "equal_range"),
  model_name = "model",
  ret = c("plot", "data"),
  pre_process_fun = function(df) df,
  feat_eng_fun = function(df) df,
  post_process_fun = function(preds, df_raw) preds,
  seed = 2024L,
  verbose = FALSE,
  ...
)
```

## Arguments

- data:

  A `data.frame` or `data.table`.

- ...:

  Arguments passed to methods.

- var:

  `[character(1)]` Feature column to vary on the x-axis.

- obs:

  `[character(1)]` Observed target column name.

- model:

  A fitted model object. Standard R models (lm, glm, xgb, ranger,
  tidymodels workflows, etc.) and H2O models are supported
  automatically - no extra arguments needed.

- exposure:

  `[character(1)]` Exposure weight column. If absent, every row is given
  weight 1. Default `"exposure"`.

- bins:

  `[integer(1)]` Number of bins for numeric `var`. Default 10.

- sample_size:

  `[integer(1)]` Rows to sample for PDP computation. Reducing this
  speeds up prediction at the cost of accuracy. Default 10,000. The full
  dataset is always used for the one-way actuals.

- type_agg:

  `[character(1)]` Binning strategy: `"equal_exposure"` (default) or
  `"equal_range"`.

- model_name:

  `[character(1)]` Label shown in the plot legend. Default `"model"`.

- ret:

  `[character(1)]` `"plot"` (default) returns a plotly object; `"data"`
  returns the aggregated data.table.

- pre_process_fun:

  `function(df) -> df` applied to the data before feature engineering.
  Default is the identity function.

- feat_eng_fun:

  `function(df) -> df` (or matrix) applied after pre-processing to
  produce the model input. Default is the identity function.

- post_process_fun:

  `function(preds, df_raw) -> numeric` applied to raw model predictions.
  Default is the identity function.

- seed:

  `[integer(1)]` Seed for the PDP row sample, applied via
  [`withr::with_seed()`](https://withr.r-lib.org/reference/with_seed.html)
  so the global RNG stream is left undisturbed. Default `2024L`.

- verbose:

  `[logical(1)]` Announce the variable being computed? Default `FALSE`.

## Value

A plotly object, or a data.table when `ret = "data"`, or `NULL` with a
warning when the variable cannot be plotted.

## Details

Alongside the PDP line the chart also shows:

- Observed mean per bin (actual target, exposure-weighted)

- Model average prediction per bin (in-sample, not PDP)

- Global average observed and predicted reference lines

- Yellow exposure bars (left axis) - identical style to
  [`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)

## See also

[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
for observed-only one-way analysis.

## Examples

``` r
# \donttest{
m <- lm(mpg ~ wt + hp + cyl, data = mtcars)

# Basic usage
pdp(mtcars, var = "wt", obs = "mpg", model = m)

{"x":{"visdat":{"1bbd65125cb7":["function () ","plotlyVisDat"]},"cur_data":"1bbd65125cb7","attrs":{"1bbd65125cb7":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"mpg","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square"},"hoverinfo":"text","hovertext":["mpg: 31.56667","mpg: 28.56667","mpg: 21.76667","mpg: 20.70000","mpg: 21.10000","mpg: 17.72500","mpg: 16.80000","mpg: 15.53333","mpg: 15.90000","mpg: 12.97500"],"inherit":true},"1bbd65125cb7.1":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999],"yaxis":"y2","type":"scatter","mode":"lines","name":"mpg Mean","line":{"color":"#9900cc"},"hoverinfo":"text","hovertext":"Mean mpg: 20.09062","inherit":true},"1bbd65125cb7.2":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"avg_pred_model","line":{"color":"#1F78B4"},"marker":{"color":"#1F78B4","symbol":"triangle-up","size":10},"hoverinfo":"text","hovertext":["avg_pred_model: 28.36317, err: -10.1%","avg_pred_model: 27.02024, err: -5.4%","avg_pred_model: 24.73662, err: 13.6%","avg_pred_model: 22.46691, err: 8.5%","avg_pred_model: 21.10340, err: 0%","avg_pred_model: 18.69510, err: 5.5%","avg_pred_model: 18.80788, err: 12%","avg_pred_model: 15.17420, err: -2.3%","avg_pred_model: 15.50812, err: -2.5%","avg_pred_model: 11.57062, err: -10.8%"],"inherit":true},"1bbd65125cb7.3":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996],"yaxis":"y2","type":"scatter","mode":"lines","name":"avg_pred_model Mean","line":{"color":"#1F78B4"},"hoverinfo":"text","hovertext":"Mean avg_pred_model: 20.09062","inherit":true},"1bbd65125cb7.4":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"pdp_model","line":{"color":null},"marker":{"color":null,"symbol":"circle","size":10},"hoverinfo":"text","hovertext":["pdp_model: 24.97806, vs global avg: 24.3%","pdp_model: 23.89020, vs global avg: 18.9%","pdp_model: 22.64716, vs global avg: 12.7%","pdp_model: 21.57831, vs global avg: 7.4%","pdp_model: 20.63614, vs global avg: 2.7%","pdp_model: 19.74147, vs global avg: -1.7%","pdp_model: 19.25850, vs global avg: -4.1%","pdp_model: 18.79929, vs global avg: -6.4%","pdp_model: 18.28466, vs global avg: -9%","pdp_model: 15.60223, vs global avg: -22.3%"],"inherit":true},"1bbd65125cb7.5":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00"},"hoverinfo":"text","hovertext":["Exposure: [1.513,1.835] = 3.000000","Exposure: (1.835,2.2] = 3.000000","Exposure: (2.2,2.62] = 3.000000","Exposure: (2.62,2.875] = 3.000000","Exposure: (2.875,3.215] = 4.000000","Exposure: (3.215,3.44] = 4.000000","Exposure: (3.44,3.52] = 2.000000","Exposure: (3.52,3.73] = 3.000000","Exposure: (3.73,3.845] = 3.000000","Exposure: (3.845,5.424] = 4.000000"],"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"xaxis":{"domain":[0,1],"automargin":true,"title":"wt","categoryorder":"array","categoryarray":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"type":"category"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Exposure","showgrid":false,"autorange":true},"yaxis2":{"overlaying":"y","side":"right","showgrid":true,"autorange":true,"title":"Observed / Predicted"},"legend":{"x":1.1499999999999999,"y":0.5},"hovermode":"x","plot_bgcolor":"rgba(0,0,0,0)","paper_bgcolor":"rgba(0,0,0,0)","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[31.566666666666663,28.566666666666666,21.766666666666666,20.699999999999999,21.099999999999998,17.725000000000001,16.800000000000001,15.533333333333333,15.9,12.974999999999998],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"mpg","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square","line":{"color":"rgba(31,119,180,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["mpg: 31.56667","mpg: 28.56667","mpg: 21.76667","mpg: 20.70000","mpg: 21.10000","mpg: 17.72500","mpg: 16.80000","mpg: 15.53333","mpg: 15.90000","mpg: 12.97500"],"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999,20.090624999999999],"yaxis":"y2","type":"scatter","mode":"lines","name":"mpg Mean","line":{"color":"#9900cc"},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062","Mean mpg: 20.09062"],"marker":{"color":"rgba(255,127,14,1)","line":{"color":"rgba(255,127,14,1)"}},"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[28.363169777715996,27.020235775615863,24.736620074233667,22.466910808101307,21.103403638850128,18.69510182341519,18.807875509171705,15.174201096073553,15.508116876740781,11.570615976787909],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"avg_pred_model","line":{"color":"#1F78B4"},"marker":{"color":"#1F78B4","symbol":"triangle-up","size":10,"line":{"color":"rgba(44,160,44,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["avg_pred_model: 28.36317, err: -10.1%","avg_pred_model: 27.02024, err: -5.4%","avg_pred_model: 24.73662, err: 13.6%","avg_pred_model: 22.46691, err: 8.5%","avg_pred_model: 21.10340, err: 0%","avg_pred_model: 18.69510, err: 5.5%","avg_pred_model: 18.80788, err: 12%","avg_pred_model: 15.17420, err: -2.3%","avg_pred_model: 15.50812, err: -2.5%","avg_pred_model: 11.57062, err: -10.8%"],"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996,20.090624999999996],"yaxis":"y2","type":"scatter","mode":"lines","name":"avg_pred_model Mean","line":{"color":"#1F78B4"},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062","Mean avg_pred_model: 20.09062"],"marker":{"color":"rgba(214,39,40,1)","line":{"color":"rgba(214,39,40,1)"}},"error_y":{"color":"rgba(214,39,40,1)"},"error_x":{"color":"rgba(214,39,40,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[24.978056253162745,23.890200989620602,22.647164043651788,21.578310618774136,20.636136118326437,19.741466214539958,19.258502815150806,18.799291714092263,18.284658583595615,15.602232358791564],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"pdp_model","line":{"color":null},"marker":{"color":null,"symbol":"circle","size":10,"line":{"color":"rgba(148,103,189,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["pdp_model: 24.97806, vs global avg: 24.3%","pdp_model: 23.89020, vs global avg: 18.9%","pdp_model: 22.64716, vs global avg: 12.7%","pdp_model: 21.57831, vs global avg: 7.4%","pdp_model: 20.63614, vs global avg: 2.7%","pdp_model: 19.74147, vs global avg: -1.7%","pdp_model: 19.25850, vs global avg: -4.1%","pdp_model: 18.79929, vs global avg: -6.4%","pdp_model: 18.28466, vs global avg: -9%","pdp_model: 15.60223, vs global avg: -22.3%"],"error_y":{"color":"rgba(148,103,189,1)"},"error_x":{"color":"rgba(148,103,189,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[3,3,3,3,4,4,2,3,3,4],"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00","line":{"color":"rgba(140,86,75,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Exposure: [1.513,1.835] = 3.000000","Exposure: (1.835,2.2] = 3.000000","Exposure: (2.2,2.62] = 3.000000","Exposure: (2.62,2.875] = 3.000000","Exposure: (2.875,3.215] = 4.000000","Exposure: (3.215,3.44] = 4.000000","Exposure: (3.44,3.52] = 2.000000","Exposure: (3.52,3.73] = 3.000000","Exposure: (3.73,3.845] = 3.000000","Exposure: (3.845,5.424] = 4.000000"],"error_y":{"color":"rgba(140,86,75,1)"},"error_x":{"color":"rgba(140,86,75,1)"},"xaxis":"x","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# GLM - predict() is dispatched automatically
g <- glm(vs ~ wt + hp, data = mtcars, family = binomial)
pdp(mtcars, var = "wt", obs = "vs", model = g)

{"x":{"visdat":{"1bbd187328b3":["function () ","plotlyVisDat"]},"cur_data":"1bbd187328b3","attrs":{"1bbd187328b3":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"vs","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square"},"hoverinfo":"text","hovertext":["vs: 1.000000","vs: 0.6666667","vs: 0.6666667","vs: 0.3333333","vs: 0.7500000","vs: 0.5000000","vs: 0.5000000","vs: 0","vs: 0","vs: 0"],"inherit":true},"1bbd187328b3.1":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375],"yaxis":"y2","type":"scatter","mode":"lines","name":"vs Mean","line":{"color":"#9900cc"},"hoverinfo":"text","hovertext":"Mean vs: 0.4375000","inherit":true},"1bbd187328b3.2":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"avg_pred_model","line":{"color":"#1F78B4"},"marker":{"color":"#1F78B4","symbol":"triangle-up","size":10},"hoverinfo":"text","hovertext":["avg_pred_model: 0.7647597, err: -23.5%","avg_pred_model: 0.9383696, err: 40.8%","avg_pred_model: 0.7827378, err: 17.4%","avg_pred_model: 0.4770936, err: 43.1%","avg_pred_model: 0.6733986, err: -10.2%","avg_pred_model: 0.3304880, err: -33.9%","avg_pred_model: 0.5034610, err: 0.7%","avg_pred_model: 0.004895112","avg_pred_model: 0.01344947","avg_pred_model: 0.008403884"],"inherit":true},"1bbd187328b3.3":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366],"yaxis":"y2","type":"scatter","mode":"lines","name":"avg_pred_model Mean","line":{"color":"#1F78B4"},"hoverinfo":"text","hovertext":"Mean avg_pred_model: 0.4375000","inherit":true},"1bbd187328b3.4":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"pdp_model","line":{"color":null},"marker":{"color":null,"symbol":"circle","size":10},"hoverinfo":"text","hovertext":["pdp_model: 0.3414584, vs global avg: -22%","pdp_model: 0.3704951, vs global avg: -15.3%","pdp_model: 0.4024827, vs global avg: -8%","pdp_model: 0.4282367, vs global avg: -2.1%","pdp_model: 0.4492207, vs global avg: 2.7%","pdp_model: 0.4675262, vs global avg: 6.9%","pdp_model: 0.4767543, vs global avg: 9%","pdp_model: 0.4851223, vs global avg: 10.9%","pdp_model: 0.4940585, vs global avg: 12.9%","pdp_model: 0.5349053, vs global avg: 22.3%"],"inherit":true},"1bbd187328b3.5":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00"},"hoverinfo":"text","hovertext":["Exposure: [1.513,1.835] = 3.000000","Exposure: (1.835,2.2] = 3.000000","Exposure: (2.2,2.62] = 3.000000","Exposure: (2.62,2.875] = 3.000000","Exposure: (2.875,3.215] = 4.000000","Exposure: (3.215,3.44] = 4.000000","Exposure: (3.44,3.52] = 2.000000","Exposure: (3.52,3.73] = 3.000000","Exposure: (3.73,3.845] = 3.000000","Exposure: (3.845,5.424] = 4.000000"],"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"xaxis":{"domain":[0,1],"automargin":true,"title":"wt","categoryorder":"array","categoryarray":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"type":"category"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Exposure","showgrid":false,"autorange":true},"yaxis2":{"overlaying":"y","side":"right","showgrid":true,"autorange":true,"title":"Observed / Predicted"},"legend":{"x":1.1499999999999999,"y":0.5},"hovermode":"x","plot_bgcolor":"rgba(0,0,0,0)","paper_bgcolor":"rgba(0,0,0,0)","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[1,0.66666666666666663,0.66666666666666663,0.33333333333333331,0.75,0.5,0.5,0,0,0],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"vs","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square","line":{"color":"rgba(31,119,180,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["vs: 1.000000","vs: 0.6666667","vs: 0.6666667","vs: 0.3333333","vs: 0.7500000","vs: 0.5000000","vs: 0.5000000","vs: 0","vs: 0","vs: 0"],"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375,0.4375],"yaxis":"y2","type":"scatter","mode":"lines","name":"vs Mean","line":{"color":"#9900cc"},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000","Mean vs: 0.4375000"],"marker":{"color":"rgba(255,127,14,1)","line":{"color":"rgba(255,127,14,1)"}},"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0.76475972506469903,0.93836959902690265,0.78273784554930226,0.47709360746468493,0.67339857158914751,0.33048804811882637,0.50346095686347381,0.0048951118214564078,0.013449469191004834,0.0084038837135409616],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"avg_pred_model","line":{"color":"#1F78B4"},"marker":{"color":"#1F78B4","symbol":"triangle-up","size":10,"line":{"color":"rgba(44,160,44,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["avg_pred_model: 0.7647597, err: -23.5%","avg_pred_model: 0.9383696, err: 40.8%","avg_pred_model: 0.7827378, err: 17.4%","avg_pred_model: 0.4770936, err: 43.1%","avg_pred_model: 0.6733986, err: -10.2%","avg_pred_model: 0.3304880, err: -33.9%","avg_pred_model: 0.5034610, err: 0.7%","avg_pred_model: 0.004895112","avg_pred_model: 0.01344947","avg_pred_model: 0.008403884"],"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366,0.43750000005522366],"yaxis":"y2","type":"scatter","mode":"lines","name":"avg_pred_model Mean","line":{"color":"#1F78B4"},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000","Mean avg_pred_model: 0.4375000"],"marker":{"color":"rgba(214,39,40,1)","line":{"color":"rgba(214,39,40,1)"}},"error_y":{"color":"rgba(214,39,40,1)"},"error_x":{"color":"rgba(214,39,40,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0.34145843280443838,0.37049507013952915,0.40248265592512911,0.4282367437028618,0.44922067341717553,0.46752623486921496,0.47675432160988573,0.48512225894477445,0.49405851489090802,0.53490529962461819],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"pdp_model","line":{"color":null},"marker":{"color":null,"symbol":"circle","size":10,"line":{"color":"rgba(148,103,189,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["pdp_model: 0.3414584, vs global avg: -22%","pdp_model: 0.3704951, vs global avg: -15.3%","pdp_model: 0.4024827, vs global avg: -8%","pdp_model: 0.4282367, vs global avg: -2.1%","pdp_model: 0.4492207, vs global avg: 2.7%","pdp_model: 0.4675262, vs global avg: 6.9%","pdp_model: 0.4767543, vs global avg: 9%","pdp_model: 0.4851223, vs global avg: 10.9%","pdp_model: 0.4940585, vs global avg: 12.9%","pdp_model: 0.5349053, vs global avg: 22.3%"],"error_y":{"color":"rgba(148,103,189,1)"},"error_x":{"color":"rgba(148,103,189,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[3,3,3,3,4,4,2,3,3,4],"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00","line":{"color":"rgba(140,86,75,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Exposure: [1.513,1.835] = 3.000000","Exposure: (1.835,2.2] = 3.000000","Exposure: (2.2,2.62] = 3.000000","Exposure: (2.62,2.875] = 3.000000","Exposure: (2.875,3.215] = 4.000000","Exposure: (3.215,3.44] = 4.000000","Exposure: (3.44,3.52] = 2.000000","Exposure: (3.52,3.73] = 3.000000","Exposure: (3.73,3.845] = 3.000000","Exposure: (3.845,5.424] = 4.000000"],"error_y":{"color":"rgba(140,86,75,1)"},"error_x":{"color":"rgba(140,86,75,1)"},"xaxis":"x","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# Return aggregated data instead of a plot
pdp(mtcars, var = "wt", obs = "mpg", model = m, ret = "data")
#>                wt obs_mean pred_mean exposure pdp_mean global_obs global_pred
#>            <char>    <num>     <num>    <int>    <num>      <num>       <num>
#>  1: [1.513,1.835] 31.56667  28.36317        3 24.97806   20.09062    20.09062
#>  2:   (1.835,2.2] 28.56667  27.02024        3 23.89020   20.09062    20.09062
#>  3:    (2.2,2.62] 21.76667  24.73662        3 22.64716   20.09062    20.09062
#>  4:  (2.62,2.875] 20.70000  22.46691        3 21.57831   20.09062    20.09062
#>  5: (2.875,3.215] 21.10000  21.10340        4 20.63614   20.09062    20.09062
#>  6:  (3.215,3.44] 17.72500  18.69510        4 19.74147   20.09062    20.09062
#>  7:   (3.44,3.52] 16.80000  18.80788        2 19.25850   20.09062    20.09062
#>  8:   (3.52,3.73] 15.53333  15.17420        3 18.79929   20.09062    20.09062
#>  9:  (3.73,3.845] 15.90000  15.50812        3 18.28466   20.09062    20.09062
#> 10: (3.845,5.424] 12.97500  11.57062        4 15.60223   20.09062    20.09062
# }
```
