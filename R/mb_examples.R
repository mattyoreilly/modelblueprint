# =============================================================================
# MB_examples.R
# Example modelblueprint constructors for common R model types.
#
# All functions share a single help page (see ?mb_examples) and are grouped
# under the "Example modelblueprints" family in the package documentation.
# =============================================================================

# mtcars is a lazy-loaded dataset from the datasets package; it is always
# available in R but cannot be imported via @importFrom. Suppress the
# R CMD check NOTE with globalVariables().
utils::globalVariables("mtcars")

# Shared 75/25 train/test split — internal, not exported
.mb_split <- function() {
  set.seed(42L)
  idx <- sample(nrow(mtcars), size = 24L)
  train <- mtcars[idx, ]
  test <- mtcars[-idx, ]
  train$vs <- as.integer(train$vs)
  test$vs <- as.integer(test$vs)
  list(train = train, test = test)
}


# =============================================================================
# Shared documentation page
# =============================================================================

#' Example modelblueprint objects
#'
#' A family of constructor functions that return ready-to-use
#' `modelblueprint` objects for common R model types. All examples use the
#' built-in `mtcars` dataset with a reproducible 75/25 train/test split.
#'
#' **Regression target:** `mpg` (continuous)
#'
#' **Classification target:** `vs` (binary 0/1)
#'
#' @details
#' Functions that wrap optional packages (`rpart`, `randomForest`, `xgboost`,
#' `h2o`) will error informatively if the package is not installed. H2O
#' functions also require a Java installation and will start an H2O cluster
#' automatically.
#'
#' `post_process_fun` is set on classification models that return a probability
#' matrix (rpart, randomForest) so that `predict()` always returns a plain
#' numeric vector of P(class = 1).
#'
#' @return A `modelblueprint` object.
#'
#' @examples
#' mb <- mb_lm_regression()
#' predict(mb, mtcars)
#' one_way(mb, var = "wt")
#'
#' mb_cls <- mb_glm_binomial()
#' predict(mb_cls, mtcars)   # returns probabilities in 0 to 1
#'
#' @name mb_examples
#' @family Example modelblueprints
NULL


# =============================================================================
# lm
# =============================================================================

#' @rdname mb_examples
#' @export
mb_lm_regression <- function() {
  d <- .mb_split()
  modelblueprint(
    model = stats::lm(mpg ~ wt + hp + cyl, data = d$train),
    train = d$train,
    test = d$test,
    y_name = "mpg",
    x_original_inputs = c("wt", "hp", "cyl"),
    model_display_name = "lm_regression",
    deploy_notes = "Linear regression: mpg ~ wt + hp + cyl"
  )
}

#' @rdname mb_examples
#' @export
mb_lm_classification <- function() {
  d <- .mb_split()
  modelblueprint(
    model = stats::lm(vs ~ wt + hp + am, data = d$train),
    train = d$train,
    test = d$test,
    y_name = "vs",
    x_original_inputs = c("wt", "hp", "am"),
    model_display_name = "lm_probability",
    deploy_notes = "Linear probability model: vs ~ wt + hp + am"
  )
}


# =============================================================================
# glm
# =============================================================================

#' @rdname mb_examples
#' @export
mb_glm_regression <- function() {
  d <- .mb_split()
  modelblueprint(
    model = stats::glm(mpg ~ wt + hp + cyl, data = d$train, family = gaussian),
    train = d$train,
    test = d$test,
    y_name = "mpg",
    x_original_inputs = c("wt", "hp", "cyl"),
    model_display_name = "glm_gaussian",
    deploy_notes = "GLM Gaussian: mpg ~ wt + hp + cyl"
  )
}

#' @rdname mb_examples
#' @export
mb_glm_binomial <- function() {
  d <- .mb_split()
  modelblueprint(
    model = stats::glm(vs ~ wt + hp + am, data = d$train, family = binomial),
    train = d$train,
    test = d$test,
    y_name = "vs",
    x_original_inputs = c("wt", "hp", "am"),
    model_display_name = "glm_binomial",
    deploy_notes = "GLM Binomial (logistic): vs ~ wt + hp + am"
  )
}

#' @rdname mb_examples
#' @export
mb_glm_poisson <- function() {
  d <- .mb_split()
  d$train$mpg_i <- as.integer(round(d$train$mpg))
  d$test$mpg_i <- as.integer(round(d$test$mpg))
  modelblueprint(
    model = stats::glm(mpg_i ~ wt + hp + cyl, data = d$train, family = poisson),
    train = d$train,
    test = d$test,
    y_name = "mpg_i",
    x_original_inputs = c("wt", "hp", "cyl"),
    model_display_name = "glm_poisson",
    deploy_notes = "GLM Poisson: rounded mpg ~ wt + hp + cyl"
  )
}


# =============================================================================
# rpart
# =============================================================================

#' @rdname mb_examples
#' @export
mb_rpart_regression <- function() {
  check_package("rpart", "mb_rpart_regression()")
  d <- .mb_split()
  modelblueprint(
    model = rpart::rpart(
      mpg ~ wt + hp + cyl + am + gear,
      data = d$train,
      method = "anova",
      control = rpart::rpart.control(maxdepth = 4L)
    ),
    train = d$train,
    test = d$test,
    y_name = "mpg",
    x_original_inputs = c("wt", "hp", "cyl", "am", "gear"),
    model_display_name = "rpart_regression",
    deploy_notes = "Decision tree (anova): mpg"
  )
}

#' @rdname mb_examples
#' @export
mb_rpart_classification <- function() {
  check_package("rpart", "mb_rpart_classification()")
  d <- .mb_split()
  modelblueprint(
    model = rpart::rpart(
      vs ~ wt + hp + am + gear + carb,
      data = d$train,
      method = "class",
      control = rpart::rpart.control(maxdepth = 4L)
    ),
    post_process_fun = function(preds, df_raw) {
      if (is.matrix(preds)) preds[, 2L] else preds
    },
    train = d$train,
    test = d$test,
    y_name = "vs",
    x_original_inputs = c("wt", "hp", "am", "gear", "carb"),
    model_display_name = "rpart_classification",
    deploy_notes = "Decision tree (class): vs"
  )
}


# =============================================================================
# randomForest
# =============================================================================

#' @rdname mb_examples
#' @export
mb_rf_regression <- function() {
  check_package("randomForest", "mb_rf_regression()")
  d <- .mb_split()
  modelblueprint(
    model = randomForest::randomForest(
      mpg ~ wt + hp + cyl + am + gear + carb,
      data = d$train,
      ntree = 200L
    ),
    train = d$train,
    test = d$test,
    y_name = "mpg",
    x_original_inputs = c("wt", "hp", "cyl", "am", "gear", "carb"),
    model_display_name = "rf_regression",
    deploy_notes = "Random forest regression: mpg"
  )
}

#' @rdname mb_examples
#' @export
mb_rf_classification <- function() {
  check_package("randomForest", "mb_rf_classification()")
  d <- .mb_split()
  modelblueprint(
    model = randomForest::randomForest(
      factor(vs) ~ wt + hp + am + gear + carb,
      data = d$train,
      ntree = 200L
    ),
    post_process_fun = function(preds, df_raw) {
      if (is.matrix(preds)) preds[, "1"] else preds
    },
    train = d$train,
    test = d$test,
    y_name = "vs",
    x_original_inputs = c("wt", "hp", "am", "gear", "carb"),
    model_display_name = "rf_classification",
    deploy_notes = "Random forest classification: vs"
  )
}


# =============================================================================
# xgboost
# =============================================================================

#' @rdname mb_examples
#' @export
mb_xgb_regression <- function() {
  check_package("xgboost", "mb_xgb_regression()")
  d <- .mb_split()
  features <- c("wt", "hp", "cyl", "am", "gear", "carb")
  modelblueprint(
    model = xgboost::xgboost(
      x = as.matrix(d$train[, features]),
      y = d$train$mpg,
      nrounds = 50L,
      params = list(objective = "reg:squarederror")
    ),
    feat_eng_fun = function(df) as.matrix(df[, features]),
    train = d$train,
    test = d$test,
    y_name = "mpg",
    x_original_inputs = features,
    model_display_name = "xgb_regression",
    deploy_notes = "XGBoost regression: mpg"
  )
}

#' @rdname mb_examples
#' @export
mb_xgb_classification <- function() {
  check_package("xgboost", "mb_xgb_classification()")
  d <- .mb_split()
  features <- c("wt", "hp", "cyl", "am", "gear", "carb")
  modelblueprint(
    model = xgboost::xgboost(
      x = as.matrix(d$train[, features]),
      y = factor(d$train$vs),
      nrounds = 50L,
      params = list(objective = "binary:logistic")
    ),
    feat_eng_fun = function(df) as.matrix(df[, features]),
    train = d$train,
    test = d$test,
    y_name = "vs",
    x_original_inputs = features,
    model_display_name = "xgb_classification",
    deploy_notes = "XGBoost binary classification: vs"
  )
}


# =============================================================================
# H2O
# =============================================================================

#' @rdname mb_examples
#' @export
mb_h2o_regression <- function() {
  check_package("h2o", "mb_h2o_regression()")
  d <- .mb_split()
  features <- c("wt", "hp", "cyl", "am", "gear", "carb")
  suppressWarnings(suppressMessages(h2o::h2o.init(nthreads = -1L)))
  h2o::h2o.no_progress()
  modelblueprint(
    model = h2o::h2o.glm(
      x = features,
      y = "mpg",
      training_frame = h2o::as.h2o(d$train),
      family = "gaussian",
      lambda_search = TRUE,
      seed = 42L
    ),
    train = d$train,
    test = d$test,
    y_name = "mpg",
    x_original_inputs = features,
    model_display_name = "h2o_glm_regression",
    deploy_notes = "H2O GLM Gaussian: mpg"
  )
}

#' @rdname mb_examples
#' @export
mb_h2o_classification <- function() {
  check_package("h2o", "mb_h2o_classification()")
  d <- .mb_split()
  features <- c("wt", "hp", "cyl", "am", "gear", "carb")
  suppressWarnings(suppressMessages(h2o::h2o.init(nthreads = -1L)))
  h2o::h2o.no_progress()
  train_h2o <- h2o::as.h2o(d$train)
  train_h2o[, "vs"] <- h2o::as.factor(train_h2o[, "vs"])
  modelblueprint(
    model = h2o::h2o.glm(
      x = features,
      y = "vs",
      training_frame = train_h2o,
      family = "binomial",
      lambda_search = TRUE,
      seed = 42L
    ),
    train = d$train,
    test = d$test,
    y_name = "vs",
    x_original_inputs = features,
    model_display_name = "h2o_glm_classification",
    deploy_notes = "H2O GLM Binomial: vs"
  )
}
