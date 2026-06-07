# =============================================================================
# test-modelblueprint.R
# Tests for modelblueprint: saveMB/loadMB, predict, one_way, pdp methods.
# =============================================================================

library(testthat)
library(modelblueprint)


# =============================================================================
# Shared fixtures
# =============================================================================

# Used by save/load and predict tests — trained on iris, predicts on iris
make_lm_mb <- function(train = iris) {
  modelblueprint(
    model = stats::lm(Sepal.Length ~ Sepal.Width, data = train),
    train = train,
    test = train,
    holdout = train,
    x_original_inputs = "Sepal.Width",
    x_names = "Sepal.Width",
    y_name = "Sepal.Length",
    yhat_name = "pred",
    expo_val = 1,
    offset_value = 0,
    model_display_name = "lm_test",
    deploy_notes = "Testing save/load cycle"
  )
}

# Used by one_way/pdp tests — trained on mtcars, predicts on mtcars
make_mb <- function() {
  modelblueprint(
    model = stats::lm(mpg ~ wt + hp + cyl, data = mtcars),
    train = mtcars,
    test = mtcars[1:16, ],
    holdout = mtcars[17:32, ],
    y_name = "mpg",
    expo_name = "exposure", # not in mtcars — falls back to unit weights
    x_original_inputs = c("wt", "hp", "cyl"),
    model_display_name = "lm_mpg"
  )
}

make_mb_expo <- function() {
  df <- mtcars
  set.seed(1L)
  df$expo <- runif(nrow(df), 0.5, 2)
  modelblueprint(
    model = stats::lm(mpg ~ wt + hp, data = df),
    train = df,
    y_name = "mpg",
    expo_name = "expo",
    model_display_name = "lm_mpg_expo"
  )
}

make_mb_no_data <- function() {
  modelblueprint(
    model = stats::lm(mpg ~ wt, data = mtcars),
    y_name = "mpg"
  )
}

make_mb_no_y <- function() {
  modelblueprint(
    model = stats::lm(mpg ~ wt, data = mtcars),
    train = mtcars
    # y_name left as NA_character_ default
  )
}

make_glm_mb <- function() {
  df <- mtcars
  df$vs <- as.integer(df$vs)
  modelblueprint(
    model = stats::glm(vs ~ wt + hp, data = df, family = binomial),
    train = df,
    y_name = "vs",
    x_original_inputs = c("wt", "hp")
  )
}

make_fe_mb <- function() {
  df_fe <- transform(mtcars, wt2 = wt^2)
  modelblueprint(
    model = stats::lm(mpg ~ wt + wt2, data = df_fe),
    feat_eng_fun = function(df) transform(df, wt2 = wt^2),
    y_name = "mpg",
    x_original_inputs = c("wt", "wt2")
  )
}

make_post_mb <- function() {
  modelblueprint(
    model = stats::lm(mpg ~ wt, data = mtcars),
    post_process_fun = function(preds, df_raw) preds * 2,
    y_name = "mpg"
  )
}

is_plotly <- function(x) inherits(x, "plotly")


# =============================================================================
# saveMB / loadMB — native R model
# =============================================================================

describe("saveMB / loadMB — native R model (lm)", {
  it("saves without error", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    expect_no_error(saveMB(mb, path = tmp, filename = "test_mb"))
  })

  it("produces a .tar.gz file", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    saveMB(mb, path = tmp, filename = "test_mb")
    expect_true(file.exists(file.path(tmp, "test_mb.tar.gz")))
  })

  it("loads without error", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    saveMB(mb, path = tmp, filename = "test_mb")
    expect_no_error(loadMB(file.path(tmp, "test_mb.tar.gz")))
  })

  it("loaded object is a modelblueprint", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    saveMB(mb, path = tmp, filename = "test_mb")
    loaded <- loadMB(file.path(tmp, "test_mb.tar.gz"))
    expect_true(S7_inherits(loaded, modelblueprint))
  })

  it("loaded object predicts without error", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    saveMB(mb, path = tmp, filename = "test_mb")
    loaded <- loadMB(file.path(tmp, "test_mb.tar.gz"))
    expect_no_error(predict(loaded, iris))
  })

  it("predictions from loaded object match original", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    orig_pred <- predict(mb, iris)
    saveMB(mb, path = tmp, filename = "test_mb")
    loaded <- loadMB(file.path(tmp, "test_mb.tar.gz"))
    loaded_pred <- predict(loaded, iris)
    expect_equal(orig_pred, loaded_pred, tolerance = 1e-6)
  })

  it("key metadata slots round-trip correctly", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    saveMB(mb, path = tmp, filename = "test_mb")
    loaded <- loadMB(file.path(tmp, "test_mb.tar.gz"))
    expect_identical(loaded@y_name, mb@y_name)
    expect_identical(loaded@x_names, mb@x_names)
    expect_identical(loaded@x_original_inputs, mb@x_original_inputs)
    expect_identical(loaded@model_display_name, mb@model_display_name)
    expect_identical(loaded@deploy_notes, mb@deploy_notes)
  })

  it("data slot dimensions are preserved", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    saveMB(mb, path = tmp, filename = "test_mb")
    loaded <- loadMB(file.path(tmp, "test_mb.tar.gz"))
    expect_equal(dim(loaded@train), dim(mb@train))
    expect_equal(dim(loaded@test), dim(mb@test))
    expect_equal(dim(loaded@holdout), dim(mb@holdout))
  })

  it("factor columns are preserved with correct levels", {
    skip_on_cran()
    df <- iris # Species is a factor
    mb <- make_lm_mb(train = df)
    tmp <- withr::local_tempdir()
    saveMB(mb, path = tmp, filename = "test_mb")
    loaded <- loadMB(file.path(tmp, "test_mb.tar.gz"))

    factor_cols <- names(Filter(is.factor, df))
    for (col in factor_cols) {
      expect_true(
        is.factor(loaded@train[[col]]),
        info = paste("Column", col, "should be factor after load")
      )
      expect_identical(
        levels(loaded@train[[col]]),
        levels(mb@train[[col]]),
        info = paste("Factor levels for", col, "differ after load")
      )
    }
  })

  it("errors informatively when archive path does not exist", {
    skip_on_cran()
    expect_error(
      loadMB("/not/a/real/path/model.tar.gz"),
      "Archive not found",
      fixed = TRUE
    )
  })

  it("uses model_display_name as filename when filename is NULL", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    mb <- make_lm_mb()
    saveMB(mb, path = tmp)
    expect_true(file.exists(file.path(tmp, "lm_test.tar.gz")))
  })
})


# =============================================================================
# saveMB / loadMB — H2O model
# =============================================================================

describe("saveMB / loadMB — H2O model (h2o.glm)", {
  it("saves, shuts down H2O, reloads and predicts correctly", {
    skip_on_cran()
    skip_if_not_installed("h2o")
    skip_if_not_installed("arrow")

    library(h2o)
    suppressWarnings(suppressMessages(h2o::h2o.init(nthreads = 1L)))
    h2o::h2o.no_progress()

    hf <- h2o::as.h2o(iris)
    h2o_glm <- h2o::h2o.glm(
      x = "Sepal.Width",
      y = "Sepal.Length",
      training_frame = hf,
      family = "gaussian",
      seed = 42L
    )

    mb <- modelblueprint(
      model = h2o_glm,
      train = iris,
      test = iris,
      x_original_inputs = "Sepal.Width",
      x_names = "Sepal.Width",
      y_name = "Sepal.Length",
      yhat_name = "pred",
      model_display_name = "h2o_glm_test"
    )

    tmp <- withr::local_tempdir()

    expect_no_error(saveMB(mb, path = tmp, filename = "test_h2o_mb"))
    expect_true(file.exists(file.path(tmp, "test_h2o_mb.tar.gz")))

    # Shut down and wait long enough for the JVM to release the port
    suppressMessages(h2o::h2o.shutdown(prompt = FALSE))
    Sys.sleep(10L)

    loaded <- NULL
    expect_no_error(
      suppressWarnings(suppressMessages(
        loaded <- loadMB(file.path(tmp, "test_h2o_mb.tar.gz"))
      ))
    )
    expect_true(S7_inherits(loaded, modelblueprint))
    expect_no_error(predict(loaded, iris))
    expect_identical(loaded@y_name, mb@y_name)
    expect_identical(loaded@x_names, mb@x_names)
    expect_identical(loaded@model_display_name, mb@model_display_name)
    expect_equal(dim(loaded@train), dim(mb@train))

    withr::defer(
      tryCatch(
        suppressMessages(h2o::h2o.shutdown(prompt = FALSE)),
        error = function(e) NULL
      )
    )
  })
})


# =============================================================================
# predict.modelblueprint — input validation
# =============================================================================

describe("predict.modelblueprint — input validation", {
  mb <- make_lm_mb()

  it("errors when newdata is missing", {
    # Base R's generic intercepts the missing argument before dispatch,
    # so we just check that an error is thrown rather than the message.
    expect_error(predict(mb))
  })

  it("errors when newdata is NULL", {
    expect_error(
      predict(mb, NULL),
      "`newdata` is required for prediction.",
      fixed = TRUE
    )
  })

  it("errors when newdata is not a data.frame or data.table", {
    expect_error(
      predict(mb, as.matrix(iris)),
      "`newdata` must be a data.frame or data.table.",
      fixed = TRUE
    )
  })

  it("errors when model is NULL — caught at construction", {
    expect_error(
      modelblueprint(model = NULL),
      "must supply a fitted model object",
      fixed = TRUE
    )
  })
})


# =============================================================================
# predict.modelblueprint — return type and shape
# =============================================================================

describe("predict.modelblueprint — return type and shape", {
  mb <- make_lm_mb()

  it("returns a numeric vector", {
    preds <- predict(mb, iris)
    expect_true(is.numeric(preds))
  })

  it("returns one prediction per row", {
    preds <- predict(mb, iris)
    expect_length(preds, nrow(iris))
  })

  it("returns finite values for a well-specified model", {
    preds <- predict(mb, iris)
    expect_true(all(is.finite(preds)))
  })

  it("accepts a data.table as newdata", {
    dt <- data.table::as.data.table(iris)
    preds <- predict(mb, dt)
    expect_true(is.numeric(preds))
    expect_length(preds, nrow(iris))
  })
})


# =============================================================================
# predict.modelblueprint — model compatibility
# =============================================================================

describe("predict.modelblueprint — model compatibility", {
  it("works with lm", {
    mb <- make_lm_mb()
    preds <- predict(mb, iris)
    expect_true(is.numeric(preds))
    expect_length(preds, nrow(iris))
  })

  it("lm predictions match stats::predict directly", {
    m <- stats::lm(Sepal.Length ~ Sepal.Width, data = iris)
    mb <- make_lm_mb()
    direct <- as.numeric(stats::predict(m, iris))
    via_mb <- predict(mb, iris)
    expect_equal(via_mb, direct, tolerance = 1e-6)
  })

  it("works with glm (binomial — returns probabilities in [0, 1])", {
    mb <- make_glm_mb()
    preds <- predict(mb, mtcars)
    expect_true(is.numeric(preds))
    expect_true(all(preds >= 0 & preds <= 1))
  })

  it("works with glm (gaussian)", {
    mb <- modelblueprint(
      model = stats::glm(mpg ~ wt, data = mtcars, family = gaussian),
      y_name = "mpg"
    )
    preds <- predict(mb, mtcars)
    expect_true(is.numeric(preds))
    expect_length(preds, nrow(mtcars))
  })

  it("works with a model whose predict() returns a matrix (coerced to vector)", {
    fake_model <- structure(list(), class = "mat_model")
    registerS3method(
      "predict",
      "mat_model",
      function(object, newdata, ...) matrix(rep(1.5, nrow(newdata)), ncol = 1L)
    )
    mb <- modelblueprint(model = fake_model)
    preds <- predict(mb, mtcars)
    expect_true(is.numeric(preds))
    expect_length(preds, nrow(mtcars))
  })

  it("errors informatively when predict() fails for an unsupported model", {
    broken_model <- structure(list(), class = "broken_model")
    mb <- modelblueprint(model = broken_model)
    expect_error(
      predict(mb, mtcars),
      "predict.*failed.*broken_model"
    )
  })
})


# =============================================================================
# predict.modelblueprint — pipeline functions
# =============================================================================

describe("predict.modelblueprint — pipeline functions", {
  it("applies feat_eng_fun before predicting", {
    mb <- make_fe_mb()
    expect_no_error(predict(mb, mtcars))
  })

  it("feat_eng_fun output is used for prediction, not raw newdata", {
    mb <- make_fe_mb()
    preds <- predict(mb, mtcars)
    m <- stats::lm(mpg ~ wt + wt2, data = transform(mtcars, wt2 = wt^2))
    direct <- as.numeric(stats::predict(m, transform(mtcars, wt2 = wt^2)))
    expect_equal(preds, direct, tolerance = 1e-6)
  })

  it("applies pre_process_fun before feat_eng_fun", {
    # Define call_order in the local test environment — not shared across tests
    local({
      call_order <- character(0)
      mb <- modelblueprint(
        model = stats::lm(mpg ~ wt, data = mtcars),
        pre_process_fun = function(df) {
          call_order <<- c(call_order, "pre")
          df
        },
        feat_eng_fun = function(df) {
          call_order <<- c(call_order, "feat")
          df
        },
        y_name = "mpg"
      )
      predict(mb, mtcars)
      expect_equal(call_order, c("pre", "feat"))
    })
  })

  it("applies post_process_fun to raw predictions", {
    mb <- make_post_mb()
    raw_mb <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      y_name = "mpg"
    )
    preds_raw <- predict(raw_mb, mtcars)
    preds_post <- predict(mb, mtcars)
    expect_equal(preds_post, preds_raw * 2, tolerance = 1e-10)
  })
})


# =============================================================================
# predict.modelblueprint — immutability
# =============================================================================

describe("predict.modelblueprint — immutability", {
  it("does not modify caller's data.frame", {
    mb <- make_fe_mb()
    df <- mtcars
    cols_before <- names(df)
    predict(mb, df)
    expect_equal(names(df), cols_before)
  })

  it("does not modify caller's data.table", {
    mb <- make_lm_mb()
    dt <- data.table::as.data.table(iris)
    cols_before <- names(dt)
    predict(mb, dt)
    expect_equal(names(dt), cols_before)
  })
})


# =============================================================================
# predict.modelblueprint — edge cases
# =============================================================================

describe("predict.modelblueprint — edge cases", {
  it("handles a single-row newdata", {
    mb <- make_lm_mb()
    preds <- predict(mb, iris[1L, ])
    expect_length(preds, 1L)
    expect_true(is.finite(preds))
  })

  it("handles newdata with extra columns not used by model", {
    mb <- make_lm_mb()
    df_extra <- iris
    df_extra$x <- rnorm(nrow(iris))
    expect_no_error(predict(mb, df_extra))
  })

  it("identity pipeline produces same result as raw predict()", {
    m <- stats::lm(Sepal.Length ~ Sepal.Width, data = iris)
    mb <- modelblueprint(model = m, y_name = "Sepal.Length")
    direct <- as.numeric(stats::predict(m, iris))
    via_mb <- predict(mb, iris)
    expect_equal(via_mb, direct, tolerance = 1e-6)
  })
})


# =============================================================================
# predict.modelblueprint — H2O
# =============================================================================

describe("predict.modelblueprint — H2O model", {
  it("H2O glm (gaussian) predictions are numeric and finite", {
    skip_on_cran()
    skip_if_not_installed("h2o")
    suppressWarnings(suppressMessages(h2o::h2o.init(nthreads = 1L)))
    h2o::h2o.no_progress()

    hf <- h2o::as.h2o(mtcars)
    h2o_m <- h2o::h2o.glm(
      x = c("wt", "hp"),
      y = "mpg",
      training_frame = hf,
      family = "gaussian",
      seed = 42L
    )
    mb <- modelblueprint(model = h2o_m, y_name = "mpg")
    preds <- predict(mb, mtcars)

    expect_true(is.numeric(preds))
    expect_length(preds, nrow(mtcars))
    expect_true(all(is.finite(preds)))

    withr::defer(tryCatch(
      suppressMessages(h2o::h2o.shutdown(prompt = FALSE)),
      error = function(e) NULL
    ))
  })

  it("H2O glm (binomial) predictions are in [0, 1]", {
    skip_on_cran()
    skip_if_not_installed("h2o")
    suppressWarnings(suppressMessages(h2o::h2o.init(nthreads = 1L)))
    h2o::h2o.no_progress()

    df <- mtcars
    df$vs <- as.factor(df$vs)
    hf <- h2o::as.h2o(df)
    h2o_m <- h2o::h2o.glm(
      x = c("wt", "hp"),
      y = "vs",
      training_frame = hf,
      family = "binomial",
      seed = 42L
    )
    mb <- modelblueprint(model = h2o_m, y_name = "vs")
    preds <- predict(mb, mtcars)

    expect_true(is.numeric(preds))
    expect_true(all(preds >= 0 & preds <= 1, na.rm = TRUE))

    withr::defer(tryCatch(
      suppressMessages(h2o::h2o.shutdown(prompt = FALSE)),
      error = function(e) NULL
    ))
  })
})


# =============================================================================
# one_way.modelblueprint — return type
# =============================================================================

describe("one_way.modelblueprint — return type", {
  mb <- make_mb()

  it("returns a plotly object by default", {
    expect_true(is_plotly(one_way(mb, var = "wt")))
  })

  it("returns a data.table when ret = 'data'", {
    d <- one_way(mb, var = "wt", ret = "data")
    expect_true(data.table::is.data.table(d))
  })

  it("returned data contains the var column named after input var", {
    d <- one_way(mb, var = "wt", ret = "data")
    expect_true("wt" %in% names(d))
  })
})


# =============================================================================
# one_way.modelblueprint — slot usage
# =============================================================================

describe("one_way.modelblueprint — slot usage", {
  mb <- make_mb()

  it("uses y_name from blueprint as obs", {
    d <- one_way(mb, var = "wt", ret = "data")
    expect_true("mpg" %in% names(d))
  })

  it("falls back to unit weights when expo_name column not in data", {
    d <- one_way(mb, var = "wt", ret = "data")
    expect_equal(sum(d$exposure), nrow(mb@train))
  })

  it("uses real exposure column when expo_name exists in data", {
    mb_expo <- make_mb_expo()
    d <- one_way(mb_expo, var = "wt", ret = "data")
    expect_false(isTRUE(all.equal(sum(d$exposure), nrow(mb_expo@train))))
  })
})


# =============================================================================
# one_way.modelblueprint — set argument
# =============================================================================

describe("one_way.modelblueprint — set argument", {
  mb <- make_mb()

  it("uses train by default", {
    d_default <- one_way(mb, var = "wt", ret = "data")
    d_train <- one_way(mb, var = "wt", set = "train", ret = "data")
    expect_equal(sum(d_default$exposure), sum(d_train$exposure))
  })

  it("uses test dataset when set = 'test'", {
    d_test <- one_way(mb, var = "wt", set = "test", ret = "data")
    expect_equal(sum(d_test$exposure), nrow(mb@test))
  })

  it("uses holdout dataset when set = 'holdout'", {
    d_holdout <- one_way(mb, var = "wt", set = "holdout", ret = "data")
    expect_equal(sum(d_holdout$exposure), nrow(mb@holdout))
  })

  it("errors informatively when chosen set is NULL", {
    mb_no_data <- make_mb_no_data()
    expect_error(
      one_way(mb_no_data, var = "wt"),
      "modelblueprint `@train` is NULL.",
      fixed = TRUE
    )
  })
})


# =============================================================================
# one_way.modelblueprint — predictions flag
# =============================================================================

describe("one_way.modelblueprint — predictions flag", {
  mb <- make_mb()

  it("predictions = FALSE returns target column only", {
    d <- one_way(mb, var = "wt", predictions = FALSE, ret = "data")
    expect_true("mpg" %in% names(d))
    expect_false(any(grepl("^\\.pred_", names(d))))
  })

  it("predictions = TRUE adds in-sample prediction column", {
    d <- one_way(mb, var = "wt", predictions = TRUE, ret = "data")
    expect_true("mpg" %in% names(d))
    expect_true(any(grepl("^\\.pred_", names(d))))
  })

  it("predictions = TRUE returns a plotly object", {
    expect_true(is_plotly(one_way(mb, var = "wt", predictions = TRUE)))
  })

  it("prediction column is named after model_display_name", {
    d <- one_way(mb, var = "wt", predictions = TRUE, ret = "data")
    expect_true(".pred_lm_mpg" %in% names(d))
  })
})


# =============================================================================
# one_way.modelblueprint — passthrough arguments
# =============================================================================

describe("one_way.modelblueprint — passthrough arguments", {
  mb <- make_mb()

  it("bins argument is respected", {
    d5 <- one_way(mb, var = "wt", bins = 5L, ret = "data")
    d10 <- one_way(mb, var = "wt", bins = 10L, ret = "data")
    expect_lte(nrow(d5), nrow(d10))
  })

  it("type_agg = 'equal_range' returns a plot", {
    expect_true(is_plotly(one_way(mb, var = "wt", type_agg = "equal_range")))
  })

  it("split argument is passed through", {
    expect_true(is_plotly(one_way(mb, var = "wt", split = "am")))
  })

  it("invalid type_agg errors", {
    expect_error(
      one_way(mb, var = "wt", type_agg = "equal_banana"),
      "should be one of",
      fixed = TRUE
    )
  })
})


# =============================================================================
# one_way.modelblueprint — validation
# =============================================================================

describe("one_way.modelblueprint — validation", {
  it("errors when y_name is not set", {
    mb_no_y <- make_mb_no_y()
    expect_error(
      one_way(mb_no_y, var = "wt"),
      "@y_name.*not set"
    )
  })

  it("handles categorical var", {
    df <- mtcars
    df$gear_f <- as.character(df$gear)
    mb2 <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = df),
      train = df,
      y_name = "mpg"
    )
    expect_true(is_plotly(one_way(mb2, var = "gear_f")))
  })
})


# =============================================================================
# pdp.modelblueprint — return type
# =============================================================================

describe("pdp.modelblueprint — return type", {
  mb <- make_mb()

  it("returns a plotly object by default", {
    expect_true(is_plotly(pdp(mb, var = "wt")))
  })

  it("returns a data.table when ret = 'data'", {
    d <- pdp(mb, var = "wt", ret = "data")
    expect_true(data.table::is.data.table(d))
  })

  it("returned data has var column named after input var", {
    d <- pdp(mb, var = "wt", ret = "data")
    expect_true("wt" %in% names(d))
  })

  it("returned data has obs_mean, pred_mean, pdp_mean, exposure columns", {
    d <- pdp(mb, var = "wt", ret = "data")
    expect_true(all(
      c("obs_mean", "pred_mean", "pdp_mean", "exposure") %in% names(d)
    ))
  })
})


# =============================================================================
# pdp.modelblueprint — slot usage
# =============================================================================

describe("pdp.modelblueprint — slot usage", {
  mb <- make_mb()

  it("uses y_name from blueprint as obs", {
    d <- pdp(mb, var = "wt", ret = "data")
    expect_true(all(
      d$obs_mean >= min(mtcars$mpg) - 1 &
        d$obs_mean <= max(mtcars$mpg) + 1,
      na.rm = TRUE
    ))
  })

  it("uses model from blueprint — pdp_mean has no NAs", {
    d <- pdp(mb, var = "wt", bins = 5L, ret = "data")
    expect_false(any(is.na(d$pdp_mean)))
  })

  it("falls back to unit weights when expo_name column not in data", {
    d <- pdp(mb, var = "wt", ret = "data")
    expect_equal(sum(d$exposure), nrow(mb@train))
  })

  it("uses real exposure when expo_name column exists", {
    mb_expo <- make_mb_expo()
    d <- pdp(mb_expo, var = "wt", ret = "data")
    expect_false(isTRUE(all.equal(sum(d$exposure), nrow(mb_expo@train))))
  })
})


# =============================================================================
# pdp.modelblueprint — set argument
# =============================================================================

describe("pdp.modelblueprint — set argument", {
  mb <- make_mb()

  it("uses train by default", {
    d_default <- pdp(mb, var = "wt", ret = "data")
    d_train <- pdp(mb, var = "wt", set = "train", ret = "data")
    expect_equal(sum(d_default$exposure), sum(d_train$exposure))
  })

  it("uses test dataset when set = 'test'", {
    d_test <- pdp(mb, var = "wt", set = "test", ret = "data")
    expect_equal(sum(d_test$exposure), nrow(mb@test))
  })

  it("uses holdout dataset when set = 'holdout'", {
    d_holdout <- pdp(mb, var = "wt", set = "holdout", ret = "data")
    expect_equal(sum(d_holdout$exposure), nrow(mb@holdout))
  })

  it("errors informatively when chosen set is NULL", {
    mb_no_data <- make_mb_no_data()
    expect_error(
      pdp(mb_no_data, var = "wt"),
      "modelblueprint `@train` is NULL.",
      fixed = TRUE
    )
  })
})


# =============================================================================
# pdp.modelblueprint — passthrough arguments
# =============================================================================

describe("pdp.modelblueprint — passthrough arguments", {
  mb <- make_mb()

  it("bins argument reduces number of rows in returned data", {
    d5 <- pdp(mb, var = "wt", bins = 5L, ret = "data")
    d10 <- pdp(mb, var = "wt", bins = 10L, ret = "data")
    expect_lte(nrow(d5), nrow(d10))
  })

  it("sample_size argument is respected (no error on small sample)", {
    expect_true(is_plotly(pdp(mb, var = "wt", sample_size = 10L)))
  })

  it("type_agg = 'equal_range' returns a plot", {
    expect_true(is_plotly(pdp(mb, var = "wt", type_agg = "equal_range")))
  })

  it("invalid type_agg errors", {
    expect_error(
      pdp(mb, var = "wt", type_agg = "equal_banana"),
      "should be one of",
      fixed = TRUE
    )
  })
})


# =============================================================================
# pdp.modelblueprint — validation
# =============================================================================

describe("pdp.modelblueprint — validation", {
  it("errors when y_name is not set", {
    mb_no_y <- make_mb_no_y()
    expect_error(
      pdp(mb_no_y, var = "wt"),
      "@y_name.*not set"
    )
  })
})


# =============================================================================
# pdp.modelblueprint — statistical properties
# =============================================================================

describe("pdp.modelblueprint — statistical properties", {
  mb <- make_mb()

  it("pdp_mean varies across bins for an informative feature", {
    d <- pdp(mb, var = "wt", bins = 8L, ret = "data")
    expect_gt(stats::sd(d$pdp_mean, na.rm = TRUE), 0.1)
  })

  it("pdp_mean is roughly flat for a feature not in the model", {
    mb_simple <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      train = mtcars,
      y_name = "mpg"
    )
    d <- pdp(mb_simple, var = "cyl", ret = "data")
    expect_lt(stats::sd(d$pdp_mean, na.rm = TRUE), 1e-6)
  })
})


# =============================================================================
# resolve_exposure — unit tests
# =============================================================================

describe("resolve_exposure", {
  it("returns expo_name when column exists in data", {
    df <- mtcars
    df$expo <- 1
    mb <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = df),
      train = df,
      y_name = "mpg",
      expo_name = "expo"
    )
    expect_equal(modelblueprint:::resolve_exposure(mb, df), "expo")
  })

  it("returns 'vec_of_ones' when column does not exist in data", {
    mb <- make_mb()
    expect_equal(modelblueprint:::resolve_exposure(mb, mtcars), "vec_of_ones")
  })

  it("returns 'vec_of_ones' when expo_name default is not in data", {
    mb <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      train = mtcars,
      y_name = "mpg"
    )
    expect_equal(modelblueprint:::resolve_exposure(mb, mtcars), "vec_of_ones")
  })
})
