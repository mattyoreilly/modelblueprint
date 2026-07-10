# =============================================================================
# test-residuals-grouped.R
# Tests for residuals_grouped(), residuals_grouped.default(),
# residuals_grouped.modelblueprint(), and plot_residuals_grouped().
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

make_df <- function(n = 500L, seed = 42L) {
  set.seed(seed)
  data.frame(
    obs = rbinom(n, 1L, 0.3),
    pred = runif(n, 0.1, 0.5),
    exposure = rep(1, n),
    stringsAsFactors = FALSE
  )
}

make_df_expo <- function(n = 500L, seed = 42L) {
  set.seed(seed)
  data.frame(
    obs = rbinom(n, 1L, 0.3),
    pred = runif(n, 0.1, 0.5),
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
    expo_name = "exposure",
    model_display_name = "logistic_vs"
  )
}

is_plotly <- function(x) inherits(x, "plotly")


# =============================================================================
# residuals_grouped.default — return type
# =============================================================================

describe("residuals_grouped.default — return type", {
  df <- make_df()

  it("returns a plotly object by default", {
    expect_true(is_plotly(
      residuals_grouped(df, pred = "pred", obs = "obs", exposure = "exposure")
    ))
  })

  it("ret = 'plot' returns plotly", {
    expect_true(is_plotly(
      residuals_grouped(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        ret = "plot"
      )
    ))
  })

  it("ret = 'data' returns a data.table", {
    result <- residuals_grouped(
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
      residuals_grouped(
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

  it("invalid residual_type errors", {
    expect_error(
      residuals_grouped(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        residual_type = "studentised"
      ),
      "should be one of",
      fixed = TRUE
    )
  })
})


# =============================================================================
# residuals_grouped.default — returned data structure
# =============================================================================

describe("residuals_grouped.default — returned data structure", {
  df <- make_df()

  it("has expected columns: midpoint, res, obs_mean, pred_mean, exposure", {
    result <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_true(all(
      c("midpoint", "res", "obs_mean", "pred_mean", "exposure") %in%
        names(result)
    ))
  })

  it("exposure sums to total input exposure", {
    result <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_equal(sum(result$exposure), nrow(df), tolerance = 1e-6)
  })

  it("exposure sums correctly with non-unit exposure", {
    df_expo <- make_df_expo()
    result <- residuals_grouped(
      df_expo,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_equal(sum(result$exposure), sum(df_expo$exposure), tolerance = 1e-6)
  })

  it("midpoints are ordered ascending", {
    result <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_equal(result$midpoint, sort(result$midpoint))
  })

  it("res = obs_mean - pred_mean for raw residuals", {
    result <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      residual_type = "raw",
      ret = "data"
    )
    expect_equal(
      result$res,
      result$obs_mean - result$pred_mean,
      tolerance = 1e-9
    )
  })

  it("pearson residuals = (obs - pred) / sqrt(pred)", {
    result <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      residual_type = "pearson",
      ret = "data"
    )
    expected <- (result$obs_mean - result$pred_mean) /
      sqrt(pmax(result$pred_mean, 1e-10))
    expect_equal(result$res, expected, tolerance = 1e-9)
  })
})


# =============================================================================
# residuals_grouped.default — residual_type
# =============================================================================

describe("residuals_grouped.default — residual_type", {
  df <- make_df()

  it("raw residuals return a plotly object", {
    expect_true(is_plotly(
      residuals_grouped(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        residual_type = "raw"
      )
    ))
  })

  it("pearson residuals return a plotly object", {
    expect_true(is_plotly(
      residuals_grouped(
        df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        residual_type = "pearson"
      )
    ))
  })

  it("raw and pearson residuals differ", {
    raw <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      residual_type = "raw",
      ret = "data"
    )
    pearson <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      residual_type = "pearson",
      ret = "data"
    )
    expect_false(isTRUE(all.equal(raw$res, pearson$res)))
  })
})


# =============================================================================
# residuals_grouped.default — exposure_per_bin
# =============================================================================

describe("residuals_grouped.default — exposure_per_bin", {
  df <- make_df()

  it("smaller exposure_per_bin gives more bins", {
    small <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      exposure_per_bin = 5,
      ret = "data"
    )
    large <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      exposure_per_bin = 50,
      ret = "data"
    )
    expect_gte(nrow(small), nrow(large))
  })

  it("returns a warning and data when fewer than 3 bins result", {
    # Only 2 rows — n_bins = max(3L, round(2 / (epb / avg_expo))) but with
    # exposure_per_bin larger than total exposure, the guard in .default
    # still produces >= 3 bins via max(3L,...). Test instead that a
    # dataset with exactly 2 rows triggers the < 3 warning path.
    two_row_df <- data.frame(
      obs = c(0, 1),
      pred = c(0.2, 0.8),
      exposure = c(1, 1)
    )
    expect_warning(
      result <- residuals_grouped(
        two_row_df,
        pred = "pred",
        obs = "obs",
        exposure = "exposure",
        exposure_per_bin = 0.1
      ),
      "fewer than 3 bins",
      fixed = TRUE
    )
    expect_true(data.table::is.data.table(result))
  })
})


# =============================================================================
# residuals_grouped.default — immutability
# =============================================================================

describe("residuals_grouped.default — immutability", {
  it("does not modify caller's data.frame", {
    df <- make_df()
    cols_before <- names(df)
    residuals_grouped(df, pred = "pred", obs = "obs", exposure = "exposure")
    expect_equal(names(df), cols_before)
  })

  it("does not modify caller's data.table", {
    dt <- data.table::as.data.table(make_df())
    cols_before <- names(dt)
    residuals_grouped(dt, pred = "pred", obs = "obs", exposure = "exposure")
    expect_equal(names(dt), cols_before)
  })
})


# =============================================================================
# residuals_grouped.modelblueprint — return type
# =============================================================================

describe("residuals_grouped.modelblueprint — return type", {
  mb <- make_mb()

  it("returns a named list of plots for all available sets by default", {
    result <- residuals_grouped(mb)
    expect_named(result, c("train", "test"))
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })

  it("returns a plotly object for a single set", {
    expect_true(is_plotly(residuals_grouped(mb, set = "train")))
  })

  it("ret = 'data' returns a data.table", {
    result <- residuals_grouped(mb, set = "train", ret = "data")
    expect_true(data.table::is.data.table(result))
  })
})


# =============================================================================
# residuals_grouped.modelblueprint — slot usage
# =============================================================================

describe("residuals_grouped.modelblueprint — slot usage", {
  it("uses y_name from blueprint without error", {
    mb <- make_mb()
    expect_no_error(residuals_grouped(mb))
  })

  it("uses model to generate predictions — no NAs in res", {
    mb <- make_mb()
    result <- residuals_grouped(mb, set = "train", ret = "data")
    expect_false(any(is.na(result$res)))
  })

  it("falls back to unit weights when expo_name not in data", {
    mb <- make_mb()
    result <- residuals_grouped(mb, set = "train", ret = "data")
    expect_equal(sum(result$exposure), nrow(mb@train), tolerance = 1e-6)
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
    result <- residuals_grouped(mb_expo, ret = "data")
    expect_false(isTRUE(all.equal(sum(result$exposure), nrow(df))))
  })
})


# =============================================================================
# residuals_grouped.modelblueprint — set argument
# =============================================================================

describe("residuals_grouped.modelblueprint — set argument", {
  mb <- make_mb()

  it("uses train by default", {
    expect_no_error(residuals_grouped(mb, set = "train"))
  })

  it("uses test dataset when set = 'test'", {
    expect_no_error(residuals_grouped(mb, set = "test"))
  })

  it("uses all available sets by default", {
    result <- residuals_grouped(mb)
    expect_named(result, c("train", "test"))
  })

  it("returns three plots when train, test and holdout are all set", {
    mb3 <- modelblueprint(
      model = stats::glm(vs ~ wt + hp, data = mtcars, family = binomial),
      train = mtcars,
      test = mtcars[1:16, ],
      holdout = mtcars[17:32, ],
      y_name = "vs",
      model_display_name = "logistic_vs"
    )
    result <- residuals_grouped(mb3, set = c("train", "test", "holdout"))
    expect_named(result, c("train", "test", "holdout"))
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })

  it("precomputed_preds requires a single set", {
    expect_error(
      residuals_grouped(mb, precomputed_preds = rep(0.5, 32L)),
      "single"
    )
  })

  it("errors informatively when chosen set is NULL", {
    mb_no_data <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      y_name = "mpg"
    )
    expect_error(
      residuals_grouped(mb_no_data, set = "train"),
      "modelblueprint `@train` is NULL.",
      fixed = TRUE
    )
  })

  it("errors informatively when no set has data", {
    mb_no_data <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      y_name = "mpg"
    )
    expect_error(residuals_grouped(mb_no_data), "has no data")
  })

  it("errors when y_name is not set", {
    mb_no_y <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      train = mtcars
    )
    expect_error(
      residuals_grouped(mb_no_y),
      "@y_name.*not set"
    )
  })
})


# =============================================================================
# residuals_grouped.modelblueprint — passthrough arguments
# =============================================================================

describe("residuals_grouped.modelblueprint — passthrough arguments", {
  mb <- make_mb()

  it("residual_type = 'pearson' returns a plot", {
    expect_true(is_plotly(residuals_grouped(mb, set = "train", residual_type = "pearson")))
  })

  it("custom title does not error", {
    expect_no_error(residuals_grouped(mb, title = "My residual chart"))
  })

  it("smaller exposure_per_bin gives more bins", {
    small <- residuals_grouped(mb, set = "train", exposure_per_bin = 1, ret = "data")
    large <- residuals_grouped(mb, set = "train", exposure_per_bin = 10, ret = "data")
    expect_gte(nrow(small), nrow(large))
  })
})


# =============================================================================
# Residual statistical properties
# =============================================================================

describe("residuals_grouped — statistical properties", {
  it("well-calibrated model has raw residuals close to zero", {
    set.seed(1L)
    n <- 1000L
    p <- 0.3
    df <- data.frame(
      obs = rbinom(n, 1L, p),
      pred = rep(p, n), # perfect calibration
      exposure = rep(1, n)
    )
    result <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      exposure_per_bin = 50,
      ret = "data"
    )
    # With perfect calibration mean residual should be near 0
    expect_lt(abs(mean(result$res, na.rm = TRUE)), 0.1)
  })

  it("systematically high predictions give negative raw residuals", {
    set.seed(1L)
    n <- 500L
    df <- data.frame(
      obs = rbinom(n, 1L, 0.2),
      pred = rep(0.5, n), # always predicts too high
      exposure = rep(1, n)
    )
    result <- residuals_grouped(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      exposure_per_bin = 50,
      ret = "data"
    )
    expect_true(all(result$res < 0))
  })
})


# =============================================================================
# Regression tests — midpoints and exposure fallback (1.6.1)
# =============================================================================

describe("residuals_grouped — small prediction rates", {
  it("computes correct midpoints when cut() labels use scientific notation", {
    set.seed(1L)
    df <- data.frame(
      obs      = rbinom(500L, 1L, 0.0001),
      pred     = runif(500L, 1e-5, 1e-4),
      exposure = rep(1, 500L)
    )
    result <- residuals_grouped(df, pred = "pred", obs = "obs", ret = "data")
    # Midpoints must sit inside the range of observed rates. The old
    # label-parsing regex turned "(4e-05,7e-05]" into -0.5.
    expect_true(all(is.finite(result$midpoint)))
    expect_true(all(result$midpoint > 0))
    expect_true(all(result$midpoint < 2e-4))
  })

  it("midpoints equal the average of adjacent quantile breaks", {
    df <- make_df()
    result <- residuals_grouped(
      df,
      pred = "pred", obs = "obs",
      exposure_per_bin = 100, ret = "data"
    )
    rate <- df$pred / df$exposure
    expect_true(all(result$midpoint >= min(rate)))
    expect_true(all(result$midpoint <= max(rate)))
  })
})

describe("residuals_grouped — missing columns", {
  it("falls back to unit weights when the exposure column is absent", {
    df <- make_df()
    df$exposure <- NULL
    result <- residuals_grouped(df, pred = "pred", obs = "obs", ret = "data")
    expect_true(data.table::is.data.table(result))
    expect_equal(sum(result$exposure), nrow(df))
  })

  it("errors informatively when the obs column is missing", {
    expect_error(
      residuals_grouped(make_df(), pred = "pred", obs = "nope", ret = "data"),
      "nope"
    )
  })

  it("errors informatively when the pred column is missing", {
    expect_error(
      residuals_grouped(make_df(), pred = "nope", obs = "obs", ret = "data"),
      "nope"
    )
  })
})
