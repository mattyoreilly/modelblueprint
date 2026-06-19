# Example modelblueprint objects

A family of constructor functions that return ready-to-use
`modelblueprint` objects for common R model types. All examples use the
built-in `mtcars` dataset with a reproducible 75/25 train/test split.

## Usage

``` r
mb_lm_regression()

mb_lm_classification()

mb_glm_regression()

mb_glm_binomial()

mb_glm_poisson()

mb_rpart_regression()

mb_rpart_classification()

mb_rf_regression()

mb_rf_classification()

mb_xgb_regression()

mb_xgb_classification()

mb_h2o_regression()

mb_h2o_classification()

mb_h2o_glm_large(n = 5000L)
```

## Arguments

- n:

  `[integer(1)]` Number of rows to simulate. Default `5000L` is enough
  to see the caching benefit of the dashboard. Use `50000L` or more to
  stress-test prediction latency on large models.

## Value

A `modelblueprint` object.

## Details

**Regression target:** `mpg` (continuous)

**Classification target:** `vs` (binary 0/1)

Functions that wrap optional packages (`rpart`, `randomForest`,
`xgboost`, `h2o`) will error informatively if the package is not
installed. H2O functions also require a Java installation and will start
an H2O cluster automatically.

`post_process_fun` is set on classification models that return a
probability matrix (rpart, randomForest) so that
[`predict()`](https://rdrr.io/r/stats/predict.html) always returns a
plain numeric vector of P(class = 1).

## Examples

``` r
mb <- mb_lm_regression()
predict(mb, mtcars)
#>  [1] 22.32234 21.63226 24.79266 20.71217 17.42918 20.15495 15.59625 23.09422
#>  [9] 22.50423 19.82821 19.82821 15.61850 16.53859 16.40329 11.89625 11.21379
#> [17] 11.11019 25.68869 27.56802 26.69760 24.31563 17.74166 17.97168 14.86559
#> [25] 16.33318 26.40583 25.32209 26.55336 16.27670 20.54108 13.69195 23.20928
one_way(mb, var = "wt")

{"x":{"visdat":{"1594956d0fec4":["function () ","plotlyVisDat"]},"cur_data":"1594956d0fec4","attrs":{"1594956d0fec4":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":[27.300000000000001,26,32.399999999999999,22.800000000000001,21.5,21,21.399999999999999,21,22.800000000000001,21.399999999999999,18.566666666666666,15.5,14.65,17.300000000000001,15.199999999999999,13.300000000000001,19.199999999999999,16.399999999999999,10.4,14.699999999999999,10.4],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"mpg","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square"},"hoverinfo":"text","hovertext":["mpg: 27.30000 ","mpg: 26.00000 ","mpg: 32.40000 ","mpg: 22.80000 ","mpg: 21.50000 ","mpg: 21.00000 ","mpg: 21.40000 ","mpg: 21.00000 ","mpg: 22.80000 ","mpg: 21.40000 ","mpg: 18.56667 ","mpg: 15.50000 ","mpg: 14.65000 ","mpg: 17.30000 ","mpg: 15.20000 ","mpg: 13.30000 ","mpg: 19.20000 ","mpg: 16.40000 ","mpg: 10.40000 ","mpg: 14.70000 ","mpg: 10.40000 "],"inherit":true},"1594956d0fec4.1":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":["1.935","2.14","2.2","2.32","2.465","2.62","2.78","2.875","3.15","3.215","3.44","3.52","3.57","3.73","3.78","3.84","3.845","4.07","5.25","5.345","5.424"],"y":[18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332],"yaxis":"y2","type":"scatter","mode":"lines","name":"mpg Mean","line":{"color":"#9900cc"},"hoverinfo":"text","hovertext":"Mean mpg: 18.95833","inherit":true},"1594956d0fec4.2":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00"},"hoverinfo":"text","hovertext":["Exposure: 1.935 = 1.000000","Exposure: 2.14 = 1.000000","Exposure: 2.2 = 1.000000","Exposure: 2.32 = 1.000000","Exposure: 2.465 = 1.000000","Exposure: 2.62 = 1.000000","Exposure: 2.78 = 1.000000","Exposure: 2.875 = 1.000000","Exposure: 3.15 = 1.000000","Exposure: 3.215 = 1.000000","Exposure: 3.44 = 3.000000","Exposure: 3.52 = 1.000000","Exposure: 3.57 = 2.000000","Exposure: 3.73 = 1.000000","Exposure: 3.78 = 1.000000","Exposure: 3.84 = 1.000000","Exposure: 3.845 = 1.000000","Exposure: 4.07 = 1.000000","Exposure: 5.25 = 1.000000","Exposure: 5.345 = 1.000000","Exposure: 5.424 = 1.000000"],"inherit":true}},"layout":{"margin":{"b":100,"l":50,"t":25,"r":50},"xaxis":{"domain":[0,1],"automargin":true,"title":"wt","categoryorder":"array","categoryarray":["1.935","2.14","2.2","2.32","2.465","2.62","2.78","2.875","3.15","3.215","3.44","3.52","3.57","3.73","3.78","3.84","3.845","4.07","5.25","5.345","5.424"],"type":"category"},"yaxis":{"domain":[0,1],"automargin":true,"title":"Exposure","showgrid":false,"autorange":true},"yaxis2":{"overlaying":"y","side":"right","showgrid":true,"autorange":true,"title":"Observed"},"legend":{"x":1.1499999999999999,"y":0.5},"hovermode":"x","plot_bgcolor":"rgba(0,0,0,0)","paper_bgcolor":"rgba(0,0,0,0)","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":["1.935","2.14","2.2","2.32","2.465","2.62","2.78","2.875","3.15","3.215","3.44","3.52","3.57","3.73","3.78","3.84","3.845","4.07","5.25","5.345","5.424"],"y":[27.300000000000001,26,32.399999999999999,22.800000000000001,21.5,21,21.399999999999999,21,22.800000000000001,21.399999999999999,18.566666666666666,15.5,14.65,17.300000000000001,15.199999999999999,13.300000000000001,19.199999999999999,16.399999999999999,10.4,14.699999999999999,10.4],"yaxis":"y2","type":"scatter","mode":"lines+markers","name":"mpg","line":{"color":"#9900cc"},"marker":{"color":"#9900cc","symbol":"square","line":{"color":"rgba(31,119,180,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text"],"hovertext":["mpg: 27.30000 ","mpg: 26.00000 ","mpg: 32.40000 ","mpg: 22.80000 ","mpg: 21.50000 ","mpg: 21.00000 ","mpg: 21.40000 ","mpg: 21.00000 ","mpg: 22.80000 ","mpg: 21.40000 ","mpg: 18.56667 ","mpg: 15.50000 ","mpg: 14.65000 ","mpg: 17.30000 ","mpg: 15.20000 ","mpg: 13.30000 ","mpg: 19.20000 ","mpg: 16.40000 ","mpg: 10.40000 ","mpg: 14.70000 ","mpg: 10.40000 "],"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","frame":null},{"x":["1.935","2.14","2.2","2.32","2.465","2.62","2.78","2.875","3.15","3.215","3.44","3.52","3.57","3.73","3.78","3.84","3.845","4.07","5.25","5.345","5.424"],"y":[18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332,18.958333333333332],"yaxis":"y2","type":"scatter","mode":"lines","name":"mpg Mean","line":{"color":"#9900cc"},"hoverinfo":["text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text"],"hovertext":["Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833","Mean mpg: 18.95833"],"marker":{"color":"rgba(255,127,14,1)","line":{"color":"rgba(255,127,14,1)"}},"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"xaxis":"x","frame":null},{"x":["1.935","2.14","2.2","2.32","2.465","2.62","2.78","2.875","3.15","3.215","3.44","3.52","3.57","3.73","3.78","3.84","3.845","4.07","5.25","5.345","5.424"],"y":[1,1,1,1,1,1,1,1,1,1,3,1,2,1,1,1,1,1,1,1,1],"yaxis":"y","type":"bar","orientation":"v","name":"Exposure","marker":{"color":"#ffff00","line":{"color":"rgba(44,160,44,1)"}},"hoverinfo":["text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text","text"],"hovertext":["Exposure: 1.935 = 1.000000","Exposure: 2.14 = 1.000000","Exposure: 2.2 = 1.000000","Exposure: 2.32 = 1.000000","Exposure: 2.465 = 1.000000","Exposure: 2.62 = 1.000000","Exposure: 2.78 = 1.000000","Exposure: 2.875 = 1.000000","Exposure: 3.15 = 1.000000","Exposure: 3.215 = 1.000000","Exposure: 3.44 = 3.000000","Exposure: 3.52 = 1.000000","Exposure: 3.57 = 2.000000","Exposure: 3.73 = 1.000000","Exposure: 3.78 = 1.000000","Exposure: 3.84 = 1.000000","Exposure: 3.845 = 1.000000","Exposure: 4.07 = 1.000000","Exposure: 5.25 = 1.000000","Exposure: 5.345 = 1.000000","Exposure: 5.424 = 1.000000"],"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"xaxis":"x","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
mb_cls <- mb_glm_binomial()
#> Warning: glm.fit: fitted probabilities numerically 0 or 1 occurred
predict(mb_cls, mtcars)   # returns probabilities in 0 to 1
#>  [1] 2.122640e-02 6.087156e-01 7.219865e-01 9.999917e-01 2.666064e-10
#>  [6] 1.000000e+00 2.220446e-16 1.000000e+00 1.000000e+00 9.996542e-01
#> [11] 9.996542e-01 5.717862e-07 1.918360e-09 4.434027e-09 1.195615e-04
#> [16] 6.873054e-06 3.177700e-10 9.999995e-01 9.999973e-01 9.998752e-01
#> [21] 9.986928e-01 1.879847e-03 4.530718e-04 2.220446e-16 2.361581e-07
#> [26] 9.999584e-01 2.875166e-01 3.373855e-11 2.220446e-16 2.220446e-16
#> [31] 2.220446e-16 3.605970e-01
```
