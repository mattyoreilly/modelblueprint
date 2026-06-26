# =============================================================================
# test-sami.R
# Tests for sami(), sami.default(), and sami.list()
#
# Conventions:
#   - One describe() block per behaviour group
#   - One it() per behaviour
#   - All expect_error() use fixed = TRUE
#   - Fixtures defined once per describe() block
# =============================================================================

library(testthat)
library(modelblueprint)


# =============================================================================
# Shared fixtures
# =============================================================================

make_df <- function(n = 300L, seed = 42L) {
  set.seed(seed)
  data.frame(
    obs = rnorm(n, mean = 100, sd = 15),
    pred1 = rnorm(n, mean = 100, sd = 15),
    pred2 = rnorm(n, mean = 105, sd = 15),
    exposure = rep(1, n),
    stringsAsFactors = FALSE
  )
}

make_mb_list <- function() {
  mb1 <- modelblueprint(
    model = stats::lm(mpg ~ wt, data = mtcars),
    train = mtcars,
    y_name = "mpg",
    model_display_name = "lm_wt"
  )
  mb2 <- modelblueprint(
    model = stats::lm(mpg ~ hp, data = mtcars),
    train = mtcars,
    y_name = "mpg",
    model_display_name = "lm_hp"
  )
  list(mb1, mb2)
}

is_plotly <- function(x) inherits(x, "plotly")


# =============================================================================
# sami.default — input validation
# =============================================================================

describe("sami.default — input validation", {
  df <- make_df()

  it("errors when pred has fewer than two columns", {
    expect_error(
      sami(df, obs = "obs", pred = "pred1", exposure = "exposure"),
      "at least two prediction column"
    )
  })

  it("errors with invalid ret", {
    expect_error(
      sami(
        df,
        obs = "obs",
        pred = c("pred1", "pred2"),
        exposure = "exposure",
        ret = "banana"
      ),
      "should be one of",
      fixed = TRUE
    )
  })

  it("errors with invalid type_agg", {
    expect_error(
      sami(
        df,
        obs = "obs",
        pred = c("pred1", "pred2"),
        exposure = "exposure",
        type_agg = "equal_banana"
      ),
      "should be one of",
      fixed = TRUE
    )
  })
})


# =============================================================================
# sami.default — return type
# =============================================================================

describe("sami.default — return type", {
  df <- make_df()

  it("returns a list by default", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure"
    )
    expect_true(is.list(result))
  })

  it("ret = 'plot' returns a list of plotly objects", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      ret = "plot"
    )
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })

  it("ret = 'data' returns a data.table", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      ret = "data"
    )
    expect_true(data.table::is.data.table(result))
  })
})


# =============================================================================
# sami.default — number and naming of plots
# =============================================================================

describe("sami.default — number and naming of plots", {
  df <- make_df()

  it("2 predictions produce 2 plots (one per ordered pair)", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      ret = "plot"
    )
    expect_length(result, 2L)
  })

  it("3 predictions produce 6 plots", {
    df$pred3 <- rnorm(nrow(df), 100)
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2", "pred3"),
      exposure = "exposure",
      ret = "plot"
    )
    expect_length(result, 6L)
  })

  it("plots are named 'challenger / base'", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      ret = "plot"
    )
    expect_true("pred2 / pred1" %in% names(result))
    expect_true("pred1 / pred2" %in% names(result))
  })
})


# =============================================================================
# sami.default — ret = 'data'
# =============================================================================

describe("sami.default — ret = 'data'", {
  df <- make_df()

  it("adds ratio columns to data", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      ret = "data"
    )
    expect_true("pred2 / pred1" %in% names(result))
    expect_true("pred1 / pred2" %in% names(result))
  })

  it("original columns are still present", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      ret = "data"
    )
    expect_true(all(c("obs", "pred1", "pred2", "exposure") %in% names(result)))
  })

  it("ratio pred2/pred1 equals pred2/pred1 values", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      ret = "data"
    )
    expected <- sig_dig(df$pred2 / df$pred1, 7L)
    expect_equal(
      as.numeric(result[["pred2 / pred1"]]),
      as.numeric(expected),
      tolerance = 1e-6
    )
  })
})


# =============================================================================
# sami.default — recalibration
# =============================================================================

describe("sami.default — recalib", {
  it("recalib = FALSE does not change predictions", {
    df <- make_df()
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      recalib = FALSE,
      ret = "data"
    )
    expect_equal(result$pred1, df$pred1, tolerance = 1e-9)
    expect_equal(result$pred2, df$pred2, tolerance = 1e-9)
  })

  it("recalib = TRUE scales predictions to match obs mean", {
    df <- make_df()
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      recalib = TRUE,
      ret = "data"
    )
    obs_mean <- mean(df$obs)
    expect_equal(mean(result$pred1), obs_mean, tolerance = 1e-6)
    expect_equal(mean(result$pred2), obs_mean, tolerance = 1e-6)
  })

  it("recalib = TRUE still returns plotly objects", {
    df <- make_df()
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      recalib = TRUE,
      ret = "plot"
    )
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })
})


# =============================================================================
# sami.default — immutability
# =============================================================================

describe("sami.default — immutability", {
  it("does not modify caller's data.frame", {
    df <- make_df()
    cols_before <- names(df)
    sami(df, obs = "obs", pred = c("pred1", "pred2"), exposure = "exposure")
    expect_equal(names(df), cols_before)
  })

  it("does not modify caller's data.table", {
    dt <- data.table::as.data.table(make_df())
    cols_before <- names(dt)
    sami(dt, obs = "obs", pred = c("pred1", "pred2"), exposure = "exposure")
    expect_equal(names(dt), cols_before)
  })
})


# =============================================================================
# sami.default — type_agg
# =============================================================================

describe("sami.default — type_agg", {
  df <- make_df()

  it("equal_exposure returns plots", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      type_agg = "equal_exposure",
      ret = "plot"
    )
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })

  it("equal_range returns plots", {
    result <- sami(
      df,
      obs = "obs",
      pred = c("pred1", "pred2"),
      exposure = "exposure",
      type_agg = "equal_range",
      ret = "plot"
    )
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })
})


# =============================================================================
# sami.list — input validation
# =============================================================================

describe("sami.list — input validation", {
  it("errors when list has fewer than 2 elements", {
    mb_list <- make_mb_list()
    expect_error(
      sami(mb_list[1L]),
      "list.*two.*modelblueprint"
    )
  })

  it("errors when list contains non-modelblueprint elements", {
    expect_error(
      sami(list(make_mb_list()[[1L]], "not_a_blueprint")),
      "elements.*modelblueprint"
    )
  })

  it("errors when model_display_name is not set and pred_names not supplied", {
    mb1 <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      train = mtcars,
      y_name = "mpg"
      # no model_display_name
    )
    mb2 <- modelblueprint(
      model = stats::lm(mpg ~ hp, data = mtcars),
      train = mtcars,
      y_name = "mpg"
    )
    expect_error(sami(list(mb1, mb2)))
  })

  it("errors when chosen set is NULL in first blueprint", {
    mb_list <- make_mb_list()
    expect_error(
      sami(mb_list, set = "holdout"),
      "modelblueprint `@holdout` is NULL",
      fixed = TRUE
    )
  })
})


# =============================================================================
# sami.list — return type
# =============================================================================

describe("sami.list — return type", {
  mb_list <- make_mb_list()

  it("returns a list of plotly objects by default", {
    result <- sami(mb_list, bins = 5L)
    expect_true(is.list(result))
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })

  it("ret = 'data' returns a data.table", {
    result <- sami(mb_list, bins = 5L, ret = "data")
    expect_true(data.table::is.data.table(result))
  })

  it("2 blueprints produce 2 plots", {
    result <- sami(mb_list, bins = 5L, ret = "plot")
    expect_length(result, 2L)
  })
})


# =============================================================================
# sami.list — pred_names argument
# =============================================================================

describe("sami.list — pred_names argument", {
  mb_list <- make_mb_list()

  it("uses model_display_name when pred_names not supplied", {
    result <- sami(mb_list, bins = 5L, ret = "data")
    expect_true("pred_lm_wt" %in% names(result))
    expect_true("pred_lm_hp" %in% names(result))
  })

  it("uses supplied pred_names", {
    result <- sami(
      mb_list,
      bins = 5L,
      ret = "data",
      pred_names = c("model_a", "model_b")
    )
    expect_true("model_a" %in% names(result))
    expect_true("model_b" %in% names(result))
  })

  it("plots named correctly with supplied pred_names", {
    result <- sami(
      mb_list,
      bins = 5L,
      ret = "plot",
      pred_names = c("model_a", "model_b")
    )
    expect_true("model_b / model_a" %in% names(result))
    expect_true("model_a / model_b" %in% names(result))
  })
})


# =============================================================================
# sami.list — recalibration
# =============================================================================

describe("sami.list — recalib", {
  mb_list <- make_mb_list()

  it("recalib = TRUE returns plots without error", {
    expect_no_error(sami(mb_list, bins = 5L, recalib = TRUE))
  })
})
