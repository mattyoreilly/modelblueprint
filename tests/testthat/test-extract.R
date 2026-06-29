# =============================================================================
# test-extract.R
# Tests for extract_* and set_* verbs defined in R/extract.R.
# =============================================================================

library(testthat)
library(modelblueprint)


# =============================================================================
# Shared fixtures
# =============================================================================

make_full_mb <- function() {
  modelblueprint(
    model              = stats::lm(mpg ~ wt + hp, data = mtcars),
    train              = mtcars,
    test               = mtcars[1:16, ],
    holdout            = mtcars[17:32, ],
    pre_process_fun    = function(df) { df$wt <- df$wt * 1; df },
    feat_eng_fun       = function(df) { df$hp2 <- df$hp^2; df },
    post_process_fun   = function(preds, df_raw) preds * 1,
    x_original_inputs  = c("wt", "hp"),
    x_names            = c("wt", "hp", "hp2"),
    y_name             = "mpg",
    yhat_name          = "pred",
    expo_name          = "exposure",
    expo_val           = 1,
    expo_0_rep         = 0.1,
    offset_name        = NA_character_,
    offset_value       = NA_real_,
    model_display_name = "lm_mpg",
    deploy_notes       = "test deployment"
  )
}

make_minimal_mb <- function() {
  modelblueprint(
    model = stats::lm(mpg ~ wt, data = mtcars)
  )
}


# =============================================================================
# extract_fit
# =============================================================================

describe("extract_fit", {
  mb <- make_full_mb()

  it("returns the model object", {
    expect_true(inherits(extract_fit(mb), "lm"))
  })

  it("returned model produces same predictions as slot access", {
    expect_identical(extract_fit(mb), mb@model)
  })

  it("errors on a non-modelblueprint input", {
    expect_error(extract_fit(list()))
  })
})


# =============================================================================
# extract_train / extract_test / extract_holdout
# =============================================================================

describe("extract_train", {
  it("returns the train data frame", {
    mb <- make_full_mb()
    expect_identical(extract_train(mb), mb@train)
  })

  it("returns NULL when train was not set", {
    mb <- make_minimal_mb()
    expect_null(extract_train(mb))
  })

  it("errors on a non-modelblueprint", {
    expect_error(extract_train("not_mb"))
  })
})

describe("extract_test", {
  it("returns the test data frame", {
    mb <- make_full_mb()
    expect_identical(extract_test(mb), mb@test)
  })

  it("returns NULL when test was not set", {
    mb <- make_minimal_mb()
    expect_null(extract_test(mb))
  })
})

describe("extract_holdout", {
  it("returns the holdout data frame", {
    mb <- make_full_mb()
    expect_identical(extract_holdout(mb), mb@holdout)
  })

  it("returns NULL when holdout was not set", {
    mb <- make_minimal_mb()
    expect_null(extract_holdout(mb))
  })
})


# =============================================================================
# extract_pre_process_fun / extract_feat_eng_fun / extract_post_process_fun
# =============================================================================

describe("extract_pre_process_fun", {
  it("returns a function", {
    mb <- make_full_mb()
    expect_true(is.function(extract_pre_process_fun(mb)))
  })

  it("returned function is identical to the stored slot", {
    mb <- make_full_mb()
    expect_identical(extract_pre_process_fun(mb), mb@pre_process_fun)
  })

  it("returns the identity function when none was set", {
    mb <- make_minimal_mb()
    f <- extract_pre_process_fun(mb)
    expect_true(is.function(f))
    df <- data.frame(x = 1)
    expect_identical(f(df), df)
  })
})

describe("extract_feat_eng_fun", {
  it("returns a function", {
    mb <- make_full_mb()
    expect_true(is.function(extract_feat_eng_fun(mb)))
  })

  it("returned function adds the engineered column", {
    mb <- make_full_mb()
    f <- extract_feat_eng_fun(mb)
    out <- f(mtcars)
    expect_true("hp2" %in% names(out))
  })
})

describe("extract_post_process_fun", {
  it("returns a function", {
    mb <- make_full_mb()
    expect_true(is.function(extract_post_process_fun(mb)))
  })

  it("returned function is identical to the stored slot", {
    mb <- make_full_mb()
    expect_identical(extract_post_process_fun(mb), mb@post_process_fun)
  })
})


# =============================================================================
# extract_original_inputs / extract_feature_names
# =============================================================================

describe("extract_original_inputs", {
  it("returns the original input names without NAs", {
    mb <- make_full_mb()
    expect_equal(extract_original_inputs(mb), c("wt", "hp"))
  })

  it("returns a zero-length vector when slot is NA", {
    mb <- make_minimal_mb()
    expect_length(extract_original_inputs(mb), 0L)
  })

  it("never returns NA values", {
    mb <- make_minimal_mb()
    expect_false(anyNA(extract_original_inputs(mb)))
  })
})

describe("extract_feature_names", {
  it("returns the engineered feature names without NAs", {
    mb <- make_full_mb()
    expect_equal(extract_feature_names(mb), c("wt", "hp", "hp2"))
  })

  it("returns a zero-length vector when slot is NA", {
    mb <- make_minimal_mb()
    expect_length(extract_feature_names(mb), 0L)
  })
})


# =============================================================================
# Scalar metadata extractors
# =============================================================================

describe("extract_target", {
  it("returns y_name", {
    mb <- make_full_mb()
    expect_equal(extract_target(mb), "mpg")
  })

  it("returns NA_character_ when not set", {
    mb <- make_minimal_mb()
    expect_true(is.na(extract_target(mb)))
  })
})

describe("extract_yhat_name", {
  it("returns yhat_name", {
    mb <- make_full_mb()
    expect_equal(extract_yhat_name(mb), "pred")
  })

  it("returns NA_character_ when not set", {
    mb <- make_minimal_mb()
    expect_true(is.na(extract_yhat_name(mb)))
  })
})

describe("extract_exposure_name", {
  it("returns expo_name", {
    mb <- make_full_mb()
    expect_equal(extract_exposure_name(mb), "exposure")
  })
})

describe("extract_exposure_value", {
  it("returns expo_val", {
    mb <- make_full_mb()
    expect_equal(extract_exposure_value(mb), 1)
  })
})

describe("extract_exposure_zero_rep", {
  it("returns expo_0_rep", {
    mb <- make_full_mb()
    expect_equal(extract_exposure_zero_rep(mb), 0.1)
  })
})

describe("extract_offset_name", {
  it("returns NA_character_ when not set", {
    mb <- make_full_mb()
    expect_true(is.na(extract_offset_name(mb)))
  })
})

describe("extract_offset_value", {
  it("returns NA_real_ when not set", {
    mb <- make_full_mb()
    expect_true(is.na(extract_offset_value(mb)))
  })
})

describe("extract_display_name", {
  it("returns model_display_name", {
    mb <- make_full_mb()
    expect_equal(extract_display_name(mb), "lm_mpg")
  })

  it("returns NA_character_ when not set", {
    mb <- make_minimal_mb()
    expect_true(is.na(extract_display_name(mb)))
  })
})

describe("extract_deploy_notes", {
  it("returns deploy_notes", {
    mb <- make_full_mb()
    expect_equal(extract_deploy_notes(mb), "test deployment")
  })

  it("returns NA_character_ when not set", {
    mb <- make_minimal_mb()
    expect_true(is.na(extract_deploy_notes(mb)))
  })
})


# =============================================================================
# set_model
# =============================================================================

describe("set_model", {
  mb <- make_full_mb()

  it("returns a modelblueprint", {
    new_m  <- stats::lm(mpg ~ cyl, data = mtcars)
    result <- set_model(mb, new_m)
    expect_true(S7_inherits(result, modelblueprint))
  })

  it("new model is stored correctly", {
    new_m  <- stats::lm(mpg ~ cyl, data = mtcars)
    result <- set_model(mb, new_m)
    expect_identical(extract_fit(result), new_m)
  })

  it("does not mutate the original", {
    original_model <- extract_fit(mb)
    new_m <- stats::lm(mpg ~ cyl, data = mtcars)
    set_model(mb, new_m)
    expect_identical(extract_fit(mb), original_model)
  })

  it("other slots are preserved", {
    new_m  <- stats::lm(mpg ~ cyl, data = mtcars)
    result <- set_model(mb, new_m)
    expect_equal(extract_target(result), extract_target(mb))
    expect_equal(extract_display_name(result), extract_display_name(mb))
    expect_identical(extract_train(result), extract_train(mb))
  })

  it("errors when x is not a modelblueprint", {
    expect_error(set_model(list(), stats::lm(mpg ~ wt, data = mtcars)))
  })
})


# =============================================================================
# set_train / set_test / set_holdout
# =============================================================================

describe("set_train", {
  mb <- make_full_mb()

  it("replaces the train split", {
    new_df <- mtcars[1:10, ]
    result <- set_train(mb, new_df)
    expect_equal(nrow(extract_train(result)), 10L)
  })

  it("does not mutate the original", {
    orig_nrow <- nrow(extract_train(mb))
    set_train(mb, mtcars[1:5, ])
    expect_equal(nrow(extract_train(mb)), orig_nrow)
  })

  it("accepts a data.table", {
    dt <- data.table::as.data.table(mtcars)
    expect_no_error(set_train(mb, dt))
  })

  it("errors when value is not a data frame", {
    expect_error(set_train(mb, "not_a_df"), "data.frame or data.table")
  })
})

describe("set_test", {
  mb <- make_full_mb()

  it("replaces the test split", {
    new_df <- mtcars[1:5, ]
    result <- set_test(mb, new_df)
    expect_equal(nrow(extract_test(result)), 5L)
  })

  it("errors when value is not a data frame", {
    expect_error(set_test(mb, 42L), "data.frame or data.table")
  })
})

describe("set_holdout", {
  mb <- make_full_mb()

  it("replaces the holdout split", {
    new_df <- mtcars[1:8, ]
    result <- set_holdout(mb, new_df)
    expect_equal(nrow(extract_holdout(result)), 8L)
  })

  it("errors when value is not a data frame", {
    expect_error(set_holdout(mb, NULL), "data.frame or data.table")
  })
})


# =============================================================================
# set_pre_process_fun / set_feat_eng_fun / set_post_process_fun
# =============================================================================

describe("set_pre_process_fun", {
  mb <- make_full_mb()

  it("replaces pre_process_fun", {
    new_fn <- function(df) { df$scaled_wt <- scale(df$wt); df }
    result <- set_pre_process_fun(mb, new_fn)
    expect_identical(extract_pre_process_fun(result), new_fn)
  })

  it("does not mutate the original", {
    orig_fn <- extract_pre_process_fun(mb)
    set_pre_process_fun(mb, function(df) df)
    expect_identical(extract_pre_process_fun(mb), orig_fn)
  })

  it("errors when value is not a function", {
    expect_error(set_pre_process_fun(mb, "not_a_fun"), "must be a function")
  })
})

describe("set_feat_eng_fun", {
  mb <- make_full_mb()

  it("replaces feat_eng_fun", {
    new_fn <- function(df) { df$wt3 <- df$wt^3; df }
    result <- set_feat_eng_fun(mb, new_fn)
    expect_identical(extract_feat_eng_fun(result), new_fn)
  })

  it("errors when value is not a function", {
    expect_error(set_feat_eng_fun(mb, 99L), "must be a function")
  })
})

describe("set_post_process_fun", {
  mb <- make_full_mb()

  it("replaces post_process_fun", {
    new_fn <- function(preds, df_raw) preds / 10
    result <- set_post_process_fun(mb, new_fn)
    expect_identical(extract_post_process_fun(result), new_fn)
  })

  it("errors when value is not a function", {
    expect_error(set_post_process_fun(mb, TRUE), "must be a function")
  })
})


# =============================================================================
# set_original_inputs / set_feature_names
# =============================================================================

describe("set_original_inputs", {
  mb <- make_full_mb()

  it("updates x_original_inputs", {
    result <- set_original_inputs(mb, c("wt", "hp", "cyl"))
    expect_equal(extract_original_inputs(result), c("wt", "hp", "cyl"))
  })

  it("does not mutate the original", {
    orig <- extract_original_inputs(mb)
    set_original_inputs(mb, c("cyl"))
    expect_equal(extract_original_inputs(mb), orig)
  })

  it("errors when value is not character", {
    expect_error(set_original_inputs(mb, 1:3), "must be a character")
  })

  it("S7 validator still fires — duplicate inputs are rejected", {
    expect_error(
      set_original_inputs(mb, c("wt", "wt")),
      "@x_original_inputs contains duplicate"
    )
  })
})

describe("set_feature_names", {
  mb <- make_full_mb()

  it("updates x_names", {
    result <- set_feature_names(mb, c("wt", "hp"))
    expect_equal(extract_feature_names(result), c("wt", "hp"))
  })

  it("errors when value is not character", {
    expect_error(set_feature_names(mb, list()), "must be a character")
  })
})


# =============================================================================
# set_target
# =============================================================================

describe("set_target", {
  mb <- make_full_mb()

  it("updates y_name", {
    # Use a column that exists in @train
    result <- set_target(mb, "cyl")
    expect_equal(extract_target(result), "cyl")
  })

  it("does not mutate the original", {
    set_target(mb, "cyl")
    expect_equal(extract_target(mb), "mpg")
  })

  it("errors when value is not a single string", {
    expect_error(set_target(mb, c("mpg", "cyl")), "must be a single string")
  })

  it("errors when value is not a character", {
    expect_error(set_target(mb, 1L), "must be a single string")
  })

  it("S7 validator fires — y_name cannot equal yhat_name", {
    expect_error(
      set_target(mb, "pred"),  # pred is mb@yhat_name
      "@y_name and @yhat_name are both"
    )
  })
})


# =============================================================================
# set_yhat_name
# =============================================================================

describe("set_yhat_name", {
  mb <- make_full_mb()

  it("updates yhat_name", {
    result <- set_yhat_name(mb, "predicted")
    expect_equal(extract_yhat_name(result), "predicted")
  })

  it("errors when value is not a single string", {
    expect_error(set_yhat_name(mb, c("a", "b")), "must be a single string")
  })

  it("S7 validator fires — yhat_name cannot equal y_name", {
    expect_error(
      set_yhat_name(mb, "mpg"),  # mpg is mb@y_name
      "@y_name and @yhat_name are both"
    )
  })
})


# =============================================================================
# set_exposure_name / set_exposure_value / set_exposure_zero_rep
# =============================================================================

describe("set_exposure_name", {
  mb <- make_full_mb()

  it("updates expo_name", {
    result <- set_exposure_name(mb, "expo")
    expect_equal(extract_exposure_name(result), "expo")
  })

  it("errors when value is not a single string", {
    expect_error(set_exposure_name(mb, 1L), "must be a single string")
  })

  it("S7 validator fires — empty string is rejected", {
    expect_error(
      set_exposure_name(mb, ""),
      "@expo_name cannot be an empty string"
    )
  })
})

describe("set_exposure_value", {
  mb <- make_full_mb()

  it("updates expo_val", {
    result <- set_exposure_value(mb, 12)
    expect_equal(extract_exposure_value(result), 12)
  })

  it("errors when value is not a single number", {
    expect_error(set_exposure_value(mb, c(1, 2)), "must be a single number")
  })

  it("S7 validator fires — non-positive expo_val is rejected", {
    expect_error(
      set_exposure_value(mb, 0),
      "@expo_val must be a single positive finite number"
    )
  })
})

describe("set_exposure_zero_rep", {
  mb <- make_full_mb()

  it("updates expo_0_rep", {
    result <- set_exposure_zero_rep(mb, 0.5)
    expect_equal(extract_exposure_zero_rep(result), 0.5)
  })

  it("errors when value is not a single number", {
    expect_error(set_exposure_zero_rep(mb, "a"), "must be a single number")
  })

  it("S7 validator fires — non-positive expo_0_rep is rejected", {
    expect_error(
      set_exposure_zero_rep(mb, -1),
      "@expo_0_rep must be a single positive finite number"
    )
  })
})


# =============================================================================
# set_offset_name / set_offset_value
# =============================================================================

describe("set_offset_name", {
  it("updates offset_name", {
    # Use a mb without train so validator skips the column-exists check
    mb     <- make_minimal_mb()
    result <- set_offset_name(mb, "off")
    expect_equal(extract_offset_name(result), "off")
  })

  it("errors when value is not a single string", {
    mb <- make_minimal_mb()
    expect_error(set_offset_name(mb, 1L), "must be a single string")
  })

  it("S7 validator fires — empty string is rejected", {
    mb <- make_minimal_mb()
    expect_error(
      set_offset_name(mb, ""),
      "@offset_name cannot be an empty string"
    )
  })
})

describe("set_offset_value", {
  mb <- make_full_mb()

  it("updates offset_value", {
    result <- set_offset_value(mb, 0.5)
    expect_equal(extract_offset_value(result), 0.5)
  })

  it("accepts NA", {
    result <- set_offset_value(mb, NA_real_)
    expect_true(is.na(extract_offset_value(result)))
  })

  it("errors when value is not a single number", {
    expect_error(set_offset_value(mb, c(1, 2)), "must be a single number")
  })

  it("S7 validator fires — Inf is rejected", {
    expect_error(
      set_offset_value(mb, Inf),
      "@offset_value must be finite"
    )
  })
})


# =============================================================================
# set_display_name / set_deploy_notes
# =============================================================================

describe("set_display_name", {
  mb <- make_full_mb()

  it("updates model_display_name", {
    result <- set_display_name(mb, "my_model_v2")
    expect_equal(extract_display_name(result), "my_model_v2")
  })

  it("errors when value is not a single string", {
    expect_error(set_display_name(mb, c("a", "b")), "must be a single string")
  })

  it("S7 validator fires — empty string is rejected", {
    expect_error(
      set_display_name(mb, ""),
      "@model_display_name cannot be an empty string"
    )
  })
})

describe("set_deploy_notes", {
  mb <- make_full_mb()

  it("updates deploy_notes", {
    result <- set_deploy_notes(mb, "v3: retrained on 2026 data")
    expect_equal(extract_deploy_notes(result), "v3: retrained on 2026 data")
  })

  it("errors when value is not a single string", {
    expect_error(set_deploy_notes(mb, 1L), "must be a single string")
  })
})


# =============================================================================
# Pipe composition
# =============================================================================

describe("pipe composition", {
  it("set_* calls chain cleanly with |>", {
    new_m <- stats::lm(mpg ~ cyl + wt, data = mtcars)
    result <- make_minimal_mb() |>
      set_model(new_m) |>
      set_target("mpg") |>
      set_display_name("chained_model") |>
      set_deploy_notes("built via pipe")

    expect_true(S7_inherits(result, modelblueprint))
    expect_equal(extract_target(result),       "mpg")
    expect_equal(extract_display_name(result), "chained_model")
    expect_equal(extract_deploy_notes(result), "built via pipe")
    expect_identical(extract_fit(result), new_m)
  })

  it("original object is unchanged after chained set_* calls", {
    mb <- make_minimal_mb()
    mb |>
      set_target("mpg") |>
      set_display_name("temp")

    expect_true(is.na(extract_target(mb)))
    expect_true(is.na(extract_display_name(mb)))
  })

  it("set_model then predict produces correct output", {
    new_m  <- stats::lm(mpg ~ wt, data = mtcars)
    result <- make_full_mb() |>
      set_model(new_m) |>
      set_feat_eng_fun(function(df) df)  # identity: no longer need hp2

    preds <- predict(result, mtcars)
    direct <- as.numeric(stats::predict(new_m, mtcars))
    expect_equal(preds, direct, tolerance = 1e-6)
  })
})
