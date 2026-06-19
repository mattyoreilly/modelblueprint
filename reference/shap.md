# SHAP Feature Importance and Dependence Plots

Computes approximate SHAP (SHapley Additive exPlanations) values using a
built-in permutation algorithm and returns either a **feature
importance** chart (signed mean SHAP per feature - purple = increases
prediction, blue = decreases prediction, sorted by magnitude) or a
**dependence** plot (mean SHAP per bin alongside exposure bars). Both
plots use the same dual-axis Plotly style as
[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
and
[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md).

## Usage

``` r
shap(data, ...)

# Default S3 method
shap(
  data,
  model,
  vars,
  exposure = "exposure",
  type = c("importance", "dependence"),
  nsim = 50L,
  sample_size = 500L,
  bins = 10L,
  type_agg = c("equal_exposure", "equal_range"),
  ret = c("plot", "data"),
  model_name = "model",
  pre_process_fun = function(df) df,
  feat_eng_fun = function(df) df,
  post_process_fun = function(preds, df_raw) preds,
  ...
)
```

## Arguments

- data:

  A `data.frame` or `data.table`. Must contain the columns named in
  `vars` and, optionally, `exposure`.

- ...:

  Unused.

- model:

  A fitted model object.

- vars:

  `[character]` Feature column names for which SHAP values are computed.

- exposure:

  `[character(1)]` Exposure weight column. If the column is absent,
  every row is given weight 1. Default `"exposure"`. Used only in the
  dependence plot (exposure bars and weighted mean SHAP line).

- type:

  `[character(1)]` Plot type: `"importance"` (default) returns a signed
  horizontal bar chart of mean SHAP per feature (purple = positive
  effect, blue = negative effect, sorted by \|SHAP\| magnitude);
  `"dependence"` returns a dual-axis chart (exposure bars + mean SHAP
  per bin) for each variable in `vars`.

- nsim:

  `[integer(1)]` Number of random permutations per observation. Higher
  values give more stable SHAP estimates at the cost of compute time.
  Default `50L`.

- sample_size:

  `[integer(1)]` Rows sampled from `data` for SHAP computation. Default
  `500L`. Seeded at 2024 for reproducibility.

- bins:

  `[integer(1)]` Number of bins for the dependence plot x-axis. Default
  `10L`.

- type_agg:

  `[character(1)]` Binning strategy for the dependence plot:
  `"equal_exposure"` (default) or `"equal_range"`.

- ret:

  `[character(1)]` `"plot"` (default) or `"data"`. `"data"` returns a
  data.table with one SHAP column per feature in `vars`.

- model_name:

  `[character(1)]` Label shown in plot titles. Default `"model"`.

- pre_process_fun:

  `function(df) -> df` applied before `feat_eng_fun`. Default is the
  identity function.

- feat_eng_fun:

  `function(df) -> df` (or matrix) that produces the model input.
  Default is the identity function.

- post_process_fun:

  `function(preds, df_raw) -> numeric` applied to raw model predictions.
  Default is the identity function.

## Value

A plotly object, a data.table (when `ret = "data"`), or a named list of
plotly objects when `type = "dependence"` and `vars` has more than one
element.

## Details

The algorithm is model-agnostic: it works with any model that has a
[`predict()`](https://rdrr.io/r/stats/predict.html) method, including
GLMs, XGBoost, randomForest, and H2O models. No external packages beyond
the modelblueprint dependencies are required.

## See also

[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md),
[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)

## Examples

``` r
# \donttest{
m <- lm(mpg ~ wt + hp + cyl + am, data = mtcars)

# Feature importance (mean |SHAP|)
shap(mtcars, model = m, vars = c("wt", "hp", "cyl", "am"),
     type = "importance", nsim = 10L, sample_size = 32L)
#> ℹ Computing SHAP values: 4 feature(s), 32 row(s), 10 permutation(s) each.

{"x":{"visdat":{"1b7035ab74e6":["function () ","plotlyVisDat"]},"cur_data":"1b7035ab74e6","attrs":{"1b7035ab74e6":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"type":"bar","orientation":"h","marker":{"color":["#9900cc","#2171B5","#9900cc","#2171B5"]},"hoverinfo":"text","hovertext":["am: +0.0092378","cyl: -0.069858","hp: +0.078518","wt: -0.054712"],"showlegend":false,"inherit":true}},"layout":{"margin":{"b":60,"l":50,"t":65,"r":150},"title":{"text":"<b>SHAP Feature Importance<\/b> &#8212; model<br><sup><span style='color:#9900cc'>&#9632;<\/span> positive effect &nbsp;<span style='color:#2171B5'>&#9632;<\/span> negative effect<\/sup>","x":0.02,"font":{"size":15}},"xaxis":{"domain":[0,1],"automargin":true,"title":"Mean SHAP Value","showgrid":true,"zeroline":true,"zerolinecolor":"rgba(80,80,80,0.6)","zerolinewidth":2},"yaxis":{"domain":[0,1],"automargin":true,"title":"","showgrid":false,"categoryorder":"array","categoryarray":["am","cyl","hp","wt"],"type":"category"},"legend":{"x":1.1499999999999999,"y":0.5},"hovermode":"y unified","plot_bgcolor":"rgba(0,0,0,0)","paper_bgcolor":"rgba(0,0,0,0)","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0.0092377981588060362,-0.069858470993443056,0.078517864242965835,-0.054711659115908751],"y":["am","cyl","hp","wt"],"type":"bar","orientation":"h","marker":{"color":["#9900cc","#2171B5","#9900cc","#2171B5"],"line":{"color":"rgba(31,119,180,1)"}},"hoverinfo":["text","text","text","text"],"hovertext":["am: +0.0092378","cyl: -0.069858","hp: +0.078518","wt: -0.054712"],"showlegend":false,"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","yaxis":"y","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# Dependence plot for one feature
shap(mtcars, model = m, vars = "wt",
     type = "dependence", nsim = 10L, sample_size = 32L)
#> ℹ Computing SHAP values: 1 feature(s), 32 row(s), 10 permutation(s) each.

{"x":{"visdat":{"1b703d239887":["function () ","plotlyVisDat"]},"cur_data":"1b703d239887","attrs":{"1b703d239887":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"mean_shap_model","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square"},"hoverinfo":"text","hovertext":["SHAP (wt): 4.016761","SHAP (wt): 2.650009","SHAP (wt): 2.374156","SHAP (wt): 1.449725","SHAP (wt): 0.5009656","SHAP (wt): -0.1737219","SHAP (wt): -0.6067887","SHAP (wt): -1.577095","SHAP (wt): -1.306194","SHAP (wt): -4.326367"],"inherit":true},"1b703d239887.1":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0,0,0,0,0,0,0,0,0,0],"yaxis":"y2","type":"scatter","mode":"lines","name":"SHAP = 0","line":{"color":"rgba(100,100,100,0.5)","dash":"dash","width":1.5},"hoverinfo":"none","showlegend":false,"inherit":true},"1b703d239887.2":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00"},"hoverinfo":"text","hovertext":["Exposure: [1.513,1.835] = 3.000000","Exposure: (1.835,2.2] = 3.000000","Exposure: (2.2,2.62] = 3.000000","Exposure: (2.62,2.875] = 3.000000","Exposure: (2.875,3.215] = 4.000000","Exposure: (3.215,3.44] = 4.000000","Exposure: (3.44,3.52] = 2.000000","Exposure: (3.52,3.73] = 3.000000","Exposure: (3.73,3.845] = 3.000000","Exposure: (3.845,5.424] = 4.000000"],"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"xaxis":{"domain":[0,1],"automargin":true,"title":"wt","categoryorder":"array","categoryarray":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"type":"category"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Exposure","showgrid":false,"autorange":true},"yaxis2":{"overlaying":"y","side":"right","showgrid":true,"autorange":true,"title":"Mean SHAP (wt)"},"legend":{"x":1.1499999999999999,"y":0.5},"hovermode":"x","plot_bgcolor":"rgba(0,0,0,0)","paper_bgcolor":"rgba(0,0,0,0)","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[4.0167605367423063,2.6500089360438022,2.3741563944242134,1.4497245699100649,0.50096559211922853,-0.17372193920263632,-0.60678870887282077,-1.5770945938515812,-1.3061943655776054,-4.3263670035333002],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"mean_shap_model","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square","line":{"color":"rgba(31,119,180,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["SHAP (wt): 4.016761","SHAP (wt): 2.650009","SHAP (wt): 2.374156","SHAP (wt): 1.449725","SHAP (wt): 0.5009656","SHAP (wt): -0.1737219","SHAP (wt): -0.6067887","SHAP (wt): -1.577095","SHAP (wt): -1.306194","SHAP (wt): -4.326367"],"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[0,0,0,0,0,0,0,0,0,0],"yaxis":"y2","type":"scatter","mode":"lines","name":"SHAP = 0","line":{"color":"rgba(100,100,100,0.5)","dash":"dash","width":1.5},"hoverinfo":["none","none","none","none","none","none","none","none","none","none"],"showlegend":false,"marker":{"color":"rgba(255,127,14,1)","line":{"color":"rgba(255,127,14,1)"}},"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"xaxis":"x","frame":null},{"x":["[1.513,1.835]","(1.835,2.2]","(2.2,2.62]","(2.62,2.875]","(2.875,3.215]","(3.215,3.44]","(3.44,3.52]","(3.52,3.73]","(3.73,3.845]","(3.845,5.424]"],"y":[3,3,3,3,4,4,2,3,3,4],"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00","line":{"color":"rgba(44,160,44,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text"],"hovertext":["Exposure: [1.513,1.835] = 3.000000","Exposure: (1.835,2.2] = 3.000000","Exposure: (2.2,2.62] = 3.000000","Exposure: (2.62,2.875] = 3.000000","Exposure: (2.875,3.215] = 4.000000","Exposure: (3.215,3.44] = 4.000000","Exposure: (3.44,3.52] = 2.000000","Exposure: (3.52,3.73] = 3.000000","Exposure: (3.73,3.845] = 3.000000","Exposure: (3.845,5.424] = 4.000000"],"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"xaxis":"x","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}# }
```
