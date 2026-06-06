# Getting started with modelblueprint

## What is a modelblueprint?

A `modelblueprint` is an S7 object that wraps a fitted model alongside
its training data, pipeline functions, and deployment metadata. The goal
is a single object that carries everything needed to reproduce
predictions, run diagnostics, and save/restore the model.

``` r

mb <- modelblueprint(
  model              = glm(vs ~ wt + hp, data = mtcars, family = binomial),
  train              = mtcars,
  y_name             = "vs",
  model_display_name = "logistic_vs",
  deploy_notes       = "Logistic regression baseline"
)

print(mb)
#> <modelblueprint::modelblueprint>
#>  @ model             :List of 30
#>  .. $ coefficients     : Named num [1:3] 7.4104 1.0033 -0.0853
#>  ..  ..- attr(*, "names")= chr [1:3] "(Intercept)" "wt" "hp"
#>  .. $ residuals        : Named num [1:32] -2.92 -3.48 1.17 1.29 -1.02 ...
#>  ..  ..- attr(*, "names")= chr [1:32] "Mazda RX4" "Mazda RX4 Wag" "Datsun 710" "Hornet 4 Drive" ...
#>  .. $ fitted.values    : Named num [1:32] 0.6572 0.7124 0.8583 0.777 0.0167 ...
#>  ..  ..- attr(*, "names")= chr [1:32] "Mazda RX4" "Mazda RX4 Wag" "Datsun 710" "Hornet 4 Drive" ...
#>  .. $ effects          : Named num [1:32] -0.775 0.853 -2.369 0.948 0.138 ...
#>  ..  ..- attr(*, "names")= chr [1:32] "(Intercept)" "wt" "hp" "" ...
#>  .. $ R                : num [1:3, 1:3] -1.58 0 0 -4.55 -1.04 ...
#>  ..  ..- attr(*, "dimnames")=List of 2
#>  ..  .. ..$ : chr [1:3] "(Intercept)" "wt" "hp"
#>  ..  .. ..$ : chr [1:3] "(Intercept)" "wt" "hp"
#>  .. $ rank             : int 3
#>  .. $ qr               :List of 5
#>  ..  ..$ qr   : num [1:32, 1:3] -1.5806 0.2864 0.2207 0.2634 0.0811 ...
#>  ..  .. ..- attr(*, "dimnames")=List of 2
#>  ..  .. .. ..$ : chr [1:32] "Mazda RX4" "Mazda RX4 Wag" "Datsun 710" "Hornet 4 Drive" ...
#>  ..  .. .. ..$ : chr [1:3] "(Intercept)" "wt" "hp"
#>  ..  ..$ rank : int 3
#>  ..  ..$ qraux: num [1:3] 1.3 1.02 1.14
#>  ..  ..$ pivot: int [1:3] 1 2 3
#>  ..  ..$ tol  : num 1e-11
#>  ..  ..- attr(*, "class")= chr "qr"
#>  .. $ family           :List of 13
#>  ..  ..$ family    : chr "binomial"
#>  ..  ..$ link      : chr "logit"
#>  ..  ..$ linkfun   :function (mu)  
#>  ..  ..$ linkinv   :function (eta)  
#>  ..  ..$ variance  :function (mu)  
#>  ..  ..$ dev.resids:function (y, mu, wt)  
#>  ..  ..$ aic       :function (y, n, mu, wt, dev)  
#>  ..  ..$ mu.eta    :function (eta)  
#>  ..  ..$ initialize: language {     if (NCOL(y) == 1) { ...
#>  ..  ..$ validmu   :function (mu)  
#>  ..  ..$ valideta  :function (eta)  
#>  ..  ..$ simulate  :function (object, nsim)  
#>  ..  ..$ dispersion: num 1
#>  ..  ..- attr(*, "class")= chr "family"
#>  .. $ linear.predictors: Named num [1:32] 0.651 0.907 1.801 1.248 -4.074 ...
#>  ..  ..- attr(*, "names")= chr [1:32] "Mazda RX4" "Mazda RX4 Wag" "Datsun 710" "Hornet 4 Drive" ...
#>  .. $ deviance         : num 16.1
#>  .. $ aic              : num 22.1
#>  .. $ null.deviance    : num 43.9
#>  .. $ iter             : int 7
#>  .. $ weights          : Named num [1:32] 0.2253 0.2049 0.1217 0.1733 0.0165 ...
#>  ..  ..- attr(*, "names")= chr [1:32] "Mazda RX4" "Mazda RX4 Wag" "Datsun 710" "Hornet 4 Drive" ...
#>  .. $ prior.weights    : Named num [1:32] 1 1 1 1 1 1 1 1 1 1 ...
#>  ..  ..- attr(*, "names")= chr [1:32] "Mazda RX4" "Mazda RX4 Wag" "Datsun 710" "Hornet 4 Drive" ...
#>  .. $ df.residual      : int 29
#>  .. $ df.null          : int 31
#>  .. $ y                : Named num [1:32] 0 0 1 1 0 1 0 1 1 1 ...
#>  ..  ..- attr(*, "names")= chr [1:32] "Mazda RX4" "Mazda RX4 Wag" "Datsun 710" "Hornet 4 Drive" ...
#>  .. $ converged        : logi TRUE
#>  .. $ boundary         : logi FALSE
#>  .. $ model            :'data.frame':    32 obs. of  3 variables:
#>  ..  ..$ vs: num [1:32] 0 0 1 1 0 1 0 1 1 1 ...
#>  ..  ..$ wt: num [1:32] 2.62 2.88 2.32 3.21 3.44 ...
#>  ..  ..$ hp: num [1:32] 110 110 93 110 175 105 245 62 95 123 ...
#>  ..  ..- attr(*, "terms")=Classes 'terms', 'formula'  language vs ~ wt + hp
#>  ..  .. .. ..- attr(*, "variables")= language list(vs, wt, hp)
#>  ..  .. .. ..- attr(*, "factors")= int [1:3, 1:2] 0 1 0 0 0 1
#>  ..  .. .. .. ..- attr(*, "dimnames")=List of 2
#>  ..  .. .. .. .. ..$ : chr [1:3] "vs" "wt" "hp"
#>  ..  .. .. .. .. ..$ : chr [1:2] "wt" "hp"
#>  ..  .. .. ..- attr(*, "term.labels")= chr [1:2] "wt" "hp"
#>  ..  .. .. ..- attr(*, "order")= int [1:2] 1 1
#>  ..  .. .. ..- attr(*, "intercept")= int 1
#>  ..  .. .. ..- attr(*, "response")= int 1
#>  ..  .. .. ..- attr(*, ".Environment")=<environment: R_GlobalEnv> 
#>  ..  .. .. ..- attr(*, "predvars")= language list(vs, wt, hp)
#>  ..  .. .. ..- attr(*, "dataClasses")= Named chr [1:3] "numeric" "numeric" "numeric"
#>  ..  .. .. .. ..- attr(*, "names")= chr [1:3] "vs" "wt" "hp"
#>  .. $ call             : language glm(formula = vs ~ wt + hp, family = binomial, data = mtcars)
#>  .. $ formula          :Class 'formula'  language vs ~ wt + hp
#>  ..  .. ..- attr(*, ".Environment")=<environment: R_GlobalEnv> 
#>  .. $ terms            :Classes 'terms', 'formula'  language vs ~ wt + hp
#>  ..  .. ..- attr(*, "variables")= language list(vs, wt, hp)
#>  ..  .. ..- attr(*, "factors")= int [1:3, 1:2] 0 1 0 0 0 1
#>  ..  .. .. ..- attr(*, "dimnames")=List of 2
#>  ..  .. .. .. ..$ : chr [1:3] "vs" "wt" "hp"
#>  ..  .. .. .. ..$ : chr [1:2] "wt" "hp"
#>  ..  .. ..- attr(*, "term.labels")= chr [1:2] "wt" "hp"
#>  ..  .. ..- attr(*, "order")= int [1:2] 1 1
#>  ..  .. ..- attr(*, "intercept")= int 1
#>  ..  .. ..- attr(*, "response")= int 1
#>  ..  .. ..- attr(*, ".Environment")=<environment: R_GlobalEnv> 
#>  ..  .. ..- attr(*, "predvars")= language list(vs, wt, hp)
#>  ..  .. ..- attr(*, "dataClasses")= Named chr [1:3] "numeric" "numeric" "numeric"
#>  ..  .. .. ..- attr(*, "names")= chr [1:3] "vs" "wt" "hp"
#>  .. $ data             :'data.frame':    32 obs. of  11 variables:
#>  ..  ..$ mpg : num [1:32] 21 21 22.8 21.4 18.7 18.1 14.3 24.4 22.8 19.2 ...
#>  ..  ..$ cyl : num [1:32] 6 6 4 6 8 6 8 4 4 6 ...
#>  ..  ..$ disp: num [1:32] 160 160 108 258 360 ...
#>  ..  ..$ hp  : num [1:32] 110 110 93 110 175 105 245 62 95 123 ...
#>  ..  ..$ drat: num [1:32] 3.9 3.9 3.85 3.08 3.15 2.76 3.21 3.69 3.92 3.92 ...
#>  ..  ..$ wt  : num [1:32] 2.62 2.88 2.32 3.21 3.44 ...
#>  ..  ..$ qsec: num [1:32] 16.5 17 18.6 19.4 17 ...
#>  ..  ..$ vs  : num [1:32] 0 0 1 1 0 1 0 1 1 1 ...
#>  ..  ..$ am  : num [1:32] 1 1 1 0 0 0 0 0 0 0 ...
#>  ..  ..$ gear: num [1:32] 4 4 4 3 3 3 3 4 4 4 ...
#>  ..  ..$ carb: num [1:32] 4 4 1 1 2 1 4 2 2 4 ...
#>  .. $ offset           : NULL
#>  .. $ control          :List of 3
#>  ..  ..$ epsilon: num 1e-08
#>  ..  ..$ maxit  : num 25
#>  ..  ..$ trace  : logi FALSE
#>  .. $ method           : chr "glm.fit"
#>  .. $ contrasts        : NULL
#>  .. $ xlevels          : Named list()
#>  .. - attr(*, "class")= chr [1:2] "glm" "lm"
#>  @ train             :'data.frame':  32 obs. of  11 variables:
#>  .. $ mpg : num  21 21 22.8 21.4 18.7 18.1 14.3 24.4 22.8 19.2 ...
#>  .. $ cyl : num  6 6 4 6 8 6 8 4 4 6 ...
#>  .. $ disp: num  160 160 108 258 360 ...
#>  .. $ hp  : num  110 110 93 110 175 105 245 62 95 123 ...
#>  .. $ drat: num  3.9 3.9 3.85 3.08 3.15 2.76 3.21 3.69 3.92 3.92 ...
#>  .. $ wt  : num  2.62 2.88 2.32 3.21 3.44 ...
#>  .. $ qsec: num  16.5 17 18.6 19.4 17 ...
#>  .. $ vs  : num  0 0 1 1 0 1 0 1 1 1 ...
#>  .. $ am  : num  1 1 1 0 0 0 0 0 0 0 ...
#>  .. $ gear: num  4 4 4 3 3 3 3 4 4 4 ...
#>  .. $ carb: num  4 4 1 1 2 1 4 2 2 4 ...
#>  @ test              : NULL
#>  @ holdout           : NULL
#>  @ pre_process_fun   : function (df)  
#>  @ feat_eng_fun      : function (df)  
#>  @ post_process_fun  : function (preds, df_raw)  
#>  @ x_original_inputs : chr NA
#>  @ x_names           : chr NA
#>  @ y_name            : chr "vs"
#>  @ yhat_name         : chr NA
#>  @ expo_name         : chr "exposure"
#>  @ expo_val          : num 1
#>  @ expo_0_rep        : num 0.1
#>  @ offset_name       : chr NA
#>  @ offset_value      : num NA
#>  @ model_display_name: chr "logistic_vs"
#>  @ deploy_notes      : chr "Logistic regression baseline"
```

## Predicting

[`predict()`](https://rdrr.io/r/stats/predict.html) applies the full
pipeline — pre-processing, feature engineering, model prediction, and
post-processing — and always returns a numeric vector.

``` r

preds <- predict(mb, mtcars)
head(preds)
#> [1] 0.65723898 0.71235830 0.85825857 0.77695352 0.01672865 0.87219975
```

## One-way analysis

[`one_way()`](../reference/one_way.md) shows the exposure-weighted mean
of the target across bins of a feature, giving a quick view of the
marginal relationship. Pass `predictions = TRUE` to overlay the model’s
in-sample predictions as a lift chart.

``` r

one_way(mb, var = "wt")
```

``` r

one_way(mb, var = "wt", predictions = TRUE)   # lift chart
```

## Partial dependence plot

[`pdp()`](../reference/pdp.md) reveals the marginal effect of a feature
on model output, controlling for all other features by averaging
predictions across the training data.

``` r

pdp(mb, var = "wt", bins = 8L)
```

## Model diagnostics

``` r

# Gains chart with Gini coefficient
gain(mb)
```

``` r


# Predicted vs observed calibration
pred_vs_obs(mb)
```

``` r


# Grouped residuals with loess trend
residuals_grouped(mb, exposure_per_bin = 5)
```

## Pipe-friendly data manipulation

[`filter()`](https://rdrr.io/r/stats/filter.html), `mutate()`, and
`left_join()` operate on the blueprint’s internal datasets and return a
new `modelblueprint` — the original is never mutated.

``` r

mb_filtered <- mb |>
  filter(cyl %in% c(4, 6)) |>
  mutate(wt_kg = wt * 453.6)

nrow(mb_filtered@train)
#> [1] 18
```

## Feature engineering pipeline

Use `feat_eng_fun` to apply transformations before prediction — the same
function is applied to both training data and new data at prediction
time.

``` r

mb_fe <- modelblueprint(
  model        = lm(mpg ~ wt + wt2, data = transform(mtcars, wt2 = wt^2)),
  feat_eng_fun = function(df) transform(df, wt2 = wt^2),
  train        = mtcars,
  y_name       = "mpg"
)

head(predict(mb_fe, mtcars))
#> [1] 22.91314 21.14211 25.19169 19.01764 17.76063 17.65463
```

## Saving and loading

[`saveMB()`](../reference/saveMB.md) serialises the complete blueprint —
model, data, and pipeline functions — to a `.tar.gz` archive.
[`loadMB()`](../reference/loadMB.md) restores it exactly.

``` r

saveMB(mb, path = tempdir(), filename = "logistic_vs")
#> modelblueprint saved: /tmp/Rtmp6TdPTJ/logistic_vs.tar.gz
mb2 <- loadMB(file.path(tempdir(), "logistic_vs.tar.gz"))

# Predictions are identical
all.equal(predict(mb, mtcars), predict(mb2, mtcars))
#> [1] TRUE
```

## Example blueprints

The package ships with example constructors for common model types:

``` r

mb_lm  <- mb_lm_regression()
mb_glm <- mb_glm_binomial()
#> Warning: glm.fit: fitted probabilities numerically 0 or 1 occurred
mb_rf  <- mb_rf_regression()     # requires randomForest
mb_xgb <- mb_xgb_classification() # requires xgboost
#> Warning in throw_err_or_depr_msg("Parameter(s) have been removed from this
#> function: ", : Parameter(s) have been removed from this function: params. This
#> warning will become an error in a future version.

# All work with the same diagnostic functions
one_way(mb_rf, var = "wt", predictions = TRUE)
```

``` r

pdp(mb_xgb, var = "hp")
```

``` r

gain(mb_glm)
```
