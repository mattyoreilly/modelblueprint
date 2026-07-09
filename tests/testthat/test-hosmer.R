# =============================================================================
# test-pred-vs-obs.R
# Tests for pred_vs_obs(), pred_vs_obs.default(), pred_vs_obs.modelblueprint()
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

make_df <- function(n = 200L, seed = 42L) {
  set.seed(seed)
  data.frame(
    obs = rbinom(n, 1L, 0.3),
    pred = runif(n, 0, 0.5),
    exposure = rep(1, n),
    stringsAsFactors = FALSE
  )
}

make_df_with_expo <- function(n = 200L, seed = 42L) {
  set.seed(seed)
  data.frame(
    obs = rbinom(n, 1L, 0.3),
    pred = runif(n, 0, 0.5),
    exposure = runif(n, 0.5, 2),
    stringsAsFactors = FALSE
  )
}

make_mb <- function() {
  modelblueprint(
    model = stats::glm(vs ~ wt + hp, data = mtcars, family = binomial),
    train = mtcars,
    test = mtcars[1:16, ],
    y_name = "vs",
    expo_name = "exposure", # not in mtcars — falls back to ones
    model_display_name = "logistic_vs"
  )
}

is_plotly <- function(x) inherits(x, "plotly")


# =============================================================================
# pred_vs_obs.default — return type
# =============================================================================

describe("pred_vs_obs.default — return type", {
  df <- make_df()

  it("returns a plotly object by default", {
    expect_true(is_plotly(
      pred_vs_obs(df, pred = "pred", obs = "obs", exposure = "exposure")
    ))
  })

  it("ret = 'plot' returns plotly", {
    expect_true(is_plotly(
      pred_vs_obs(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        ret = "plot"
      )
    ))
  })

  it("ret = 'data' returns a data.table", {
    result <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_true(data.table::is.data.table(result))
  })

  it("invalid ret errors", {
    expect_error(
      pred_vs_obs(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        ret = "banana"
      ),
      "should be one of",
      fixed = TRUE
    )
  })

  it("invalid type_agg errors", {
    expect_error(
      pred_vs_obs(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        type_agg = "equal_banana"
      ),
      "should be one of",
      fixed = TRUE
    )
  })
})


# =============================================================================
# pred_vs_obs.default — returned data structure
# =============================================================================

describe("pred_vs_obs.default — returned data structure", {
  df <- make_df()

  it("has expected columns: .bin, obs_mean, pred_mean, exposure", {
    result <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_true(all(
      c(".bin", "obs_mean", "pred_mean", "exposure") %in% names(result)
    ))
  })

  it("has at most bins rows", {
    result <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      bins = 5L,
      ret = "data"
    )
    expect_lte(nrow(result), 5L)
  })

  it("obs_mean values are non-negative", {
    result <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_true(all(result$obs_mean >= 0, na.rm = TRUE))
  })

  it("pred_mean values are non-negative", {
    result <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_true(all(result$pred_mean >= 0, na.rm = TRUE))
  })

  it("exposure sums to total exposure in data", {
    result <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_equal(sum(result$exposure), nrow(df), tolerance = 1e-6)
  })

  it("exposure sums correctly with non-unit exposure", {
    df_expo <- make_df_with_expo()
    result <- pred_vs_obs(
      df_expo,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_equal(sum(result$exposure), sum(df_expo$exposure), tolerance = 1e-6)
  })
})


# =============================================================================
# pred_vs_obs.default — bins argument
# =============================================================================

describe("pred_vs_obs.default — bins argument", {
  df <- make_df()

  it("fewer bins produces fewer rows", {
    d5 <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      bins = 5L,
      ret = "data"
    )
    d10 <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      bins = 10L,
      ret = "data"
    )
    expect_lte(nrow(d5), nrow(d10))
  })

  it("bins = 2 does not error", {
    expect_no_error(
      pred_vs_obs(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        bins = 2L
      )
    )
  })

  it("large bins value still returns a plot", {
    expect_true(is_plotly(
      pred_vs_obs(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        bins = 50L
      )
    ))
  })
})


# =============================================================================
# pred_vs_obs.default — type_agg
# =============================================================================

describe("pred_vs_obs.default — type_agg", {
  df <- make_df()

  it("equal_exposure returns a plotly object", {
    expect_true(is_plotly(
      pred_vs_obs(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        type_agg = "equal_exposure"
      )
    ))
  })

  it("equal_range returns a plotly object", {
    expect_true(is_plotly(
      pred_vs_obs(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        type_agg = "equal_range"
      )
    ))
  })

  it("equal_exposure bins have more balanced exposure than equal_range", {
    d_ee <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      bins = 8L,
      type_agg = "equal_exposure",
      ret = "data"
    )
    d_er <- pred_vs_obs(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      bins = 8L,
      type_agg = "equal_range",
      ret = "data"
    )
    cv <- function(x) stats::sd(x) / mean(x)
    expect_lt(cv(d_ee$exposure), cv(d_er$exposure))
  })
})


# =============================================================================
# pred_vs_obs.default — immutability
# =============================================================================

describe("pred_vs_obs.default — immutability", {
  it("does not modify caller's data.frame", {
    df <- make_df()
    cols_before <- names(df)
    pred_vs_obs(df, pred = "pred", obs = "obs", exposure = "exposure")
    expect_equal(names(df), cols_before)
  })

  it("does not modify caller's data.table", {
    dt <- data.table::as.data.table(make_df())
    cols_before <- names(dt)
    pred_vs_obs(dt, pred = "pred", obs = "obs", exposure = "exposure")
    expect_equal(names(dt), cols_before)
  })
})


# =============================================================================
# pred_vs_obs.modelblueprint — return type
# =============================================================================

describe("pred_vs_obs.modelblueprint — return type", {
  mb <- make_mb()

  it("returns a named list of plots for all available sets by default", {
    result <- pred_vs_obs(mb)
    expect_named(result, c("train", "test"))
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })

  it("returns a plotly object for a single set", {
    expect_true(is_plotly(pred_vs_obs(mb, set = "train")))
  })

  it("ret = 'data' returns a data.table", {
    result <- pred_vs_obs(mb, set = "train", ret = "data")
    expect_true(data.table::is.data.table(result))
  })
})


# =============================================================================
# pred_vs_obs.modelblueprint — slot usage
# =============================================================================

describe("pred_vs_obs.modelblueprint — slot usage", {
  it("uses y_name from blueprint", {
    mb <- make_mb()
    expect_no_error(pred_vs_obs(mb))
  })

  it("uses model to generate predictions", {
    mb <- make_mb()
    result <- pred_vs_obs(mb, set = "train", ret = "data")
    expect_false(any(is.na(result$pred_mean)))
  })

  it("falls back to unit weights when expo_name not in data", {
    mb <- make_mb() # expo_name = "exposure" but mtcars has no such col
    result <- pred_vs_obs(mb, set = "train", ret = "data")
    expect_equal(sum(result$exposure), nrow(mb@train))
  })

  it("uses real exposure when expo_name column exists", {
    df <- mtcars
    set.seed(1L)
    df$expo <- runif(nrow(df), 0.5, 2)
    mb_expo <- modelblueprint(
      model = stats::glm(vs ~ wt + hp, data = df, family = binomial),
      train = df,
      y_name = "vs",
      expo_name = "expo",
      model_display_name = "logistic_vs_expo"
    )
    result <- pred_vs_obs(mb_expo, ret = "data")
    expect_false(isTRUE(all.equal(sum(result$exposure), nrow(df))))
  })
})


# =============================================================================
# pred_vs_obs.modelblueprint — set argument
# =============================================================================

describe("pred_vs_obs.modelblueprint — set argument", {
  mb <- make_mb()

  it("uses train by default", {
    expect_no_error(pred_vs_obs(mb, set = "train"))
  })

  it("uses test dataset when set = 'test'", {
    expect_no_error(pred_vs_obs(mb, set = "test"))
  })

  it("uses all available sets by default", {
    result <- pred_vs_obs(mb)
    expect_named(result, c("train", "test"))
  })

  it("precomputed_preds requires a single set", {
    expect_error(
      pred_vs_obs(mb, precomputed_preds = rep(0.5, 32L)),
      "single"
    )
  })

  it("errors informatively when chosen set is NULL", {
    mb_no_data <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      y_name = "mpg"
    )
    expect_error(
      pred_vs_obs(mb_no_data, set = "train"),
      "modelblueprint `@train` is NULL.",
      fixed = TRUE
    )
  })

  it("errors informatively when no set has data", {
    mb_no_data <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      y_name = "mpg"
    )
    expect_error(pred_vs_obs(mb_no_data), "has no data")
  })

  it("errors when y_name is not set", {
    mb_no_y <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      train = mtcars
    )
    expect_error(
      pred_vs_obs(mb_no_y),
      "@y_name.*not set"
    )
  })
})


# =============================================================================
# pred_vs_obs.modelblueprint — passthrough arguments
# =============================================================================

describe("pred_vs_obs.modelblueprint — passthrough arguments", {
  mb <- make_mb()

  it("bins argument is respected", {
    d5 <- pred_vs_obs(mb, set = "train", bins = 5L, ret = "data")
    d10 <- pred_vs_obs(mb, set = "train", bins = 10L, ret = "data")
    expect_lte(nrow(d5), nrow(d10))
  })

  it("type_agg = 'equal_range' returns a plot", {
    expect_true(is_plotly(pred_vs_obs(mb, set = "train", type_agg = "equal_range")))
  })

  it("custom title does not error", {
    expect_no_error(pred_vs_obs(mb, title = "My calibration chart"))
  })
})


# =============================================================================
# bin_pred — unit tests
# =============================================================================

describe("bin_pred", {
  it("returns a list with integer idx and numeric breaks", {
    x <- runif(100L)
    result <- modelblueprint:::bin_pred(x, 10L, "equal_exposure")
    expect_type(result, "list")
    expect_true(is.integer(result$idx))
    expect_true(is.numeric(result$breaks))
  })

  it("equal_exposure — max bin index <= bins", {
    x <- runif(200L)
    result <- modelblueprint:::bin_pred(x, 10L, "equal_exposure")
    expect_lte(max(result$idx, na.rm = TRUE), 10L)
  })

  it("equal_range — max bin index <= bins", {
    x <- runif(200L)
    result <- modelblueprint:::bin_pred(x, 10L, "equal_range")
    expect_lte(max(result$idx, na.rm = TRUE), 10L)
  })

  it("equal_exposure — bins have more balanced counts than equal_range", {
    set.seed(1L)
    x <- c(runif(180L, 0, 0.1), runif(20L, 0.9, 1)) # skewed distribution
    b_ee <- modelblueprint:::bin_pred(x, 5L, "equal_exposure")
    b_er <- modelblueprint:::bin_pred(x, 5L, "equal_range")
    cv <- function(b) {
      counts <- as.numeric(table(b$idx))
      stats::sd(counts) / mean(counts)
    }
    expect_lt(cv(b_ee), cv(b_er))
  })

  it("no NAs in idx for clean input", {
    x <- seq(0.01, 1, length.out = 100L)
    result <- modelblueprint:::bin_pred(x, 5L, "equal_exposure")
    expect_false(any(is.na(result$idx)))
  })
})


# =============================================================================
# make_interval_labels — unit tests
# =============================================================================

describe("make_interval_labels", {
  it("returns n labels for n+1 breaks", {
    breaks <- c(0, 0.25, 0.5, 0.75, 1)
    labels <- modelblueprint:::make_interval_labels(breaks)
    expect_length(labels, 4L)
  })

  it("labels are character strings", {
    breaks <- c(0, 0.5, 1)
    labels <- modelblueprint:::make_interval_labels(breaks)
    expect_type(labels, "character")
  })

  it("labels contain parentheses and brackets", {
    breaks <- c(0, 0.5, 1)
    labels <- modelblueprint:::make_interval_labels(breaks)
    expect_true(all(grepl("^\\(.*\\]$", labels)))
  })
})


# =============================================================================
# Regression tests — exposure fallback and column validation (1.6.1)
# =============================================================================

describe("pred_vs_obs — missing columns", {
  it("falls back to unit weights when the exposure column is absent", {
    set.seed(21L)
    df <- data.frame(
      observed = rnorm(100L, 10),
      predict  = rnorm(100L, 10)
    )
    result <- pred_vs_obs(df, ret = "data")
    expect_true(data.table::is.data.table(result))
    expect_equal(sum(result$exposure), nrow(df))
  })

  it("errors informatively when the obs column is missing", {
    df <- data.frame(predict = 1:5, exposure = 1)
    expect_error(pred_vs_obs(df, ret = "data"), "observed")
  })

  it("errors informatively when the pred column is missing", {
    df <- data.frame(observed = 1:5, exposure = 1)
    expect_error(pred_vs_obs(df, ret = "data"), "predict")
  })
})
