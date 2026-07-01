# Getting started with modelblueprint

## What is a modelblueprint?

A `modelblueprint` is an S7 object that wraps a fitted model alongside
its training data, pipeline functions, and deployment metadata. The goal
is a single object that carries everything needed to reproduce
predictions, run diagnostics, and save/restore the model.

The example below fits a Poisson frequency model on a small synthetic
car insurance dataset. `claim_freq` (claims per unit exposure) is the
target; `nclaims` is the raw count modelled with a log-exposure offset.

``` r

# Synthetic car insurance data ------------------------------------------------
set.seed(42L)
n   <- 500L
ins <- data.frame(
  driver_age  = sample(18L:75L, n, replace = TRUE),
  vehicle_age = sample(0L:15L,  n, replace = TRUE),
  gender      = sample(c("M", "F"), n, replace = TRUE),
  exposure    = round(runif(n, 0.1, 1.0), 2)
)
ins$nclaims    <- rpois(n, lambda = ins$exposure * exp(
  log(0.08) + ifelse(ins$driver_age < 25, 0.5, 0) + 0.01 * ins$vehicle_age
))
ins$claim_freq <- ins$nclaims / ins$exposure
train <- ins[1:400, ]
test  <- ins[401:500, ]

# Wrap the fitted model -------------------------------------------------------
mb <- modelblueprint(
  model = glm(
    nclaims ~ driver_age + vehicle_age + gender + offset(log(exposure)),
    data   = train,
    family = poisson
  ),
  post_process_fun   = function(preds, df_raw) preds / df_raw$exposure,
  train              = train,
  test               = test,
  y_name             = "claim_freq",
  expo_name          = "exposure",
  x_original_inputs  = c("driver_age", "vehicle_age", "gender"),
  model_display_name = "glm_poisson_freq",
  deploy_notes       = "GLM Poisson frequency: motor third-party liability"
)

print(mb)
#> ============================================================ 
#> modelblueprint
#> ============================================================ 
#>   Model:        glm/lm
#>   Display name: glm_poisson_freq
#>   Target:       claim_freq
#>   Exposure:     exposure (val = 1)
#>   Features:     3 original / 0 engineered
#> ------------------------------------------------------------ 
#>   Train rows:   400
#>   Test rows:    100
#>   Holdout rows: <not set>
#> ------------------------------------------------------------ 
#>   Notes: GLM Poisson frequency: motor third-party liability
#> ============================================================
```

## Predicting

[`predict()`](https://rdrr.io/r/stats/predict.html) applies the full
pipeline — pre-processing, feature engineering, model prediction, and
post-processing — and always returns a numeric vector. The
`post_process_fun` above converts predicted counts to predicted claim
frequency automatically.

``` r

preds <- predict(mb, test)
head(preds)
#> [1] 0.09290636 0.10934320 0.11104538 0.08933154 0.13278561 0.13381670
```

## One-way analysis

[`one_way()`](https://mattyoreilly.github.io/modelblueprint/reference/one_way.md)
shows the exposure-weighted mean of the target across bins of a feature,
giving a quick view of the marginal relationship. Pass
`predictions = TRUE` to overlay the model’s in-sample predictions as a
lift chart.

``` r

one_way(mb, var = "driver_age", bins = 5)
```

``` r

one_way(mb, var = "driver_age", predictions = TRUE, bins = 5)   # lift chart
```

## Partial dependence plot

[`pdp()`](https://mattyoreilly.github.io/modelblueprint/reference/pdp.md)
reveals the marginal effect of a feature on model output, controlling
for all other features by averaging predictions across the training
data.

``` r

pdp(mb, var = "driver_age", bins = 10)
#> ℹ Calculating pdp for `driver_age`
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

## Feature engineering pipeline

Use `feat_eng_fun` to apply transformations before prediction — the same
function is applied to both training data and new data at prediction
time.

``` r

mb_fe <- modelblueprint(
  model = glm(
    nclaims ~ driver_age + driver_age2 + vehicle_age + offset(log(exposure)),
    data   = transform(train, driver_age2 = driver_age^2),
    family = poisson
  ),
  feat_eng_fun       = function(df) transform(df, driver_age2 = driver_age^2),
  post_process_fun   = function(preds, df_raw) preds / df_raw$exposure,
  train              = train,
  y_name             = "claim_freq",
  expo_name          = "exposure"
)

head(predict(mb_fe, test))
#> [1] 0.07629813 0.12936442 0.14925420 0.07331023 0.17461602 0.11211892
```

## Saving and loading

[`savemb()`](https://mattyoreilly.github.io/modelblueprint/reference/saveMB.md)
serialises the complete blueprint — model, data, and pipeline functions
— to a `.tar.gz` archive.
[`loadmb()`](https://mattyoreilly.github.io/modelblueprint/reference/loadMB.md)
restores it exactly.

``` r

savemb(mb, path = tempdir(), filename = "glm_poisson_freq")
#> ✔ modelblueprint saved:
#> /tmp/Rtmp5OPW7N/glm_poisson_freq.tar.gz
mb2 <- loadmb(file.path(tempdir(), "glm_poisson_freq.tar.gz"))

# Predictions are identical
all.equal(predict(mb, test), predict(mb2, test))
#> [1] TRUE
```
