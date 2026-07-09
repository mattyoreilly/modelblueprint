# =============================================================================
# test-gain.R
# Tests for gain(), gain.default(), gain.modelblueprint(), and internals.
#
# Conventions:
#   - One describe() block per function/behaviour group
#   - One it() per behaviour
#   - All expect_error() use fixed = TRUE
#   - Fixtures defined once per describe() block
# =============================================================================

library(testthat)
library(modelblueprint)


# =============================================================================
# Shared fixtures
# =============================================================================

# Small deterministic dataset with a clear signal
make_gain_df <- function(n = 200L, seed = 42L) {
  set.seed(seed)
  data.frame(
    obs = sample(0L:1L, n, replace = TRUE),
    pred = runif(n),
    exposure = rep(1, n),
    stringsAsFactors = FALSE
  )
}

# Perfect model — pred == obs, should give Gini near 1
make_perfect_df <- function(n = 200L) {
  data.frame(
    obs = c(rep(0L, n / 2L), rep(1L, n / 2L)),
    pred = c(rep(0, n / 2L), rep(1, n / 2L)),
    exposure = rep(1, n)
  )
}

# Random model — pred unrelated to obs, Gini near 0
make_random_df <- function(n = 1000L, seed = 1L) {
  set.seed(seed)
  data.frame(
    obs = sample(0L:1L, n, replace = TRUE),
    pred = runif(n),
    exposure = rep(1, n)
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
# gain.default — return type
# =============================================================================

describe("gain.default — return type", {
  df <- make_gain_df()

  it("returns a plotly object by default", {
    expect_true(is_plotly(gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure"
    )))
  })

  it("ret = 'plot' returns plotly", {
    expect_true(is_plotly(gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "plot"
    )))
  })

  it("ret = 'data' returns a list", {
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_true(is.list(result))
  })

  it("ret = 'data' list has length 2 (perfect + 1 score)", {
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_length(result, 2L)
  })

  it("ret = 'gini' returns a list of numeric values", {
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "gini"
    )
    expect_true(is.list(result))
    expect_true(all(vapply(result, is.numeric, logical(1L))))
  })

  it("ret = 'data' elements are data.tables", {
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_true(all(vapply(result, data.table::is.data.table, logical(1L))))
  })

  it("invalid ret errors", {
    expect_error(
      gain(
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

  it("missing obs (default NA) errors clearly", {
    expect_error(
      gain(df, pred = "pred", exposure = "exposure"),
      "obs",
      fixed = TRUE
    )
  })

  it("obs column not in data errors clearly", {
    expect_error(
      gain(df, pred = "pred", obs = "not_a_column", exposure = "exposure"),
      "not found",
      fixed = TRUE
    )
  })

  it("pred column not in data errors clearly", {
    expect_error(
      gain(df, pred = "not_a_column", obs = "obs", exposure = "exposure"),
      "not found",
      fixed = TRUE
    )
  })
})


# =============================================================================
# gain.default — multiple scores
# =============================================================================

describe("gain.default — multiple scores", {
  df <- make_gain_df()
  df$pred2 <- runif(nrow(df))

  it("accepts a vector of pred column names", {
    expect_true(is_plotly(
      gain(df, pred = c("pred", "pred2"), obs = "obs", exposure = "exposure")
    ))
  })

  it("ret = 'data' has length n_scores + 1 (perfect model)", {
    result <- gain(
      df,
      pred = c("pred", "pred2"),
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    expect_length(result, 3L) # perfect + pred + pred2
  })

  it("ret = 'gini' returns one gini per score plus perfect", {
    result <- gain(
      df,
      pred = c("pred", "pred2"),
      obs = "obs",
      exposure = "exposure",
      ret = "gini"
    )
    expect_length(result, 3L)
  })
})


# =============================================================================
# gain.default — Gini statistical properties
# =============================================================================

describe("gain.default — Gini statistical properties", {
  it("perfect model has Gini close to 1", {
    df <- make_perfect_df()
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "gini"
    )
    # result[[1]] is perfect model (Gini = 0 baseline), result[[2]] is our pred
    gini <- as.numeric(result[[2L]])
    expect_gt(gini, 0.45)
  })

  it("random model has Gini close to 0", {
    df <- make_random_df()
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "gini"
    )
    gini <- abs(as.numeric(result[[2L]]))
    expect_lt(gini, 0.15)
  })

  it("Gini values are in [-1, 1]", {
    df <- make_gain_df()
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "gini"
    )
    ginis <- as.numeric(unlist(result))
    expect_true(all(ginis >= -1 & ginis <= 1))
  })
})


# =============================================================================
# gain.default — immutability
# =============================================================================

describe("gain.default — immutability", {
  it("does not modify caller's data.frame", {
    df <- make_gain_df()
    cols_before <- names(df)
    nrow_before <- nrow(df)
    gain(df, pred = "pred", obs = "obs", exposure = "exposure")
    expect_equal(names(df), cols_before)
    expect_equal(nrow(df), nrow_before)
  })

  it("does not modify caller's data.table", {
    dt <- data.table::as.data.table(make_gain_df())
    cols_before <- names(dt)
    gain(dt, pred = "pred", obs = "obs", exposure = "exposure")
    expect_equal(names(dt), cols_before)
  })
})


# =============================================================================
# gain.default — data structure
# =============================================================================

describe("gain.default — returned data structure", {
  it("each data.table has two columns (cum_exposure, cum_score)", {
    df <- make_gain_df()
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    for (d in result) {
      expect_equal(ncol(d), 2L)
    }
  })

  it("cumulative values are in [0, 1]", {
    df <- make_gain_df()
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    for (d in result) {
      expect_true(all(unlist(d) >= 0 & unlist(d) <= 1 + 1e-9))
    }
  })

  it("cumulative exposure ends at 1", {
    df <- make_gain_df()
    result <- gain(
      df,
      pred = "pred",
      obs = "obs",
      exposure = "exposure",
      ret = "data"
    )
    for (d in result) {
      expect_equal(max(d[[1L]]), 1, tolerance = 1e-6)
    }
  })
})


# =============================================================================
# gain.modelblueprint
# =============================================================================

describe("gain.modelblueprint — return type", {
  mb <- make_mb()

  it("returns a named list of plots for all available sets by default", {
    result <- gain(mb)
    expect_named(result, c("train", "test"))
    expect_true(all(vapply(result, is_plotly, logical(1L))))
  })

  it("returns a plotly object for a single set", {
    expect_true(is_plotly(gain(mb, set = "train")))
  })

  it("ret = 'data' returns a list", {
    result <- gain(mb, set = "train", ret = "data")
    expect_true(is.list(result))
  })

  it("ret = 'gini' returns a list of numerics", {
    result <- gain(mb, set = "train", ret = "gini")
    expect_true(is.list(result))
    expect_true(all(vapply(result, is.numeric, logical(1L))))
  })
})


describe("gain.modelblueprint — slot usage", {
  mb <- make_mb()

  it("uses y_name from blueprint", {
    # Should not error — y_name = 'vs' exists in mtcars
    expect_no_error(gain(mb))
  })

  it("uses model_display_name as legend label (no error)", {
    expect_no_error(gain(mb, ret = "plot"))
  })

  it("falls back to unit weights when expo_name not in data", {
    # expo_name = "exposure" but mtcars has no such column
    expect_no_error(gain(mb, ret = "data"))
  })
})


describe("gain.modelblueprint — set argument", {
  mb <- make_mb()

  it("uses train by default", {
    expect_no_error(gain(mb, set = "train"))
  })

  it("uses test dataset when set = 'test'", {
    expect_no_error(gain(mb, set = "test"))
  })

  it("skips NULL sets when multiple sets are requested", {
    result <- gain(mb, set = c("train", "test", "holdout"))
    expect_named(result, c("train", "test"))
  })

  it("precomputed_preds requires a single set", {
    expect_error(
      gain(mb, precomputed_preds = rep(0.5, 32L)),
      "single"
    )
  })

  it("errors informatively when chosen set is NULL", {
    mb_no_data <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      y_name = "mpg"
    )
    expect_error(
      gain(mb_no_data, set = "train"),
      "modelblueprint `@train` is NULL.",
      fixed = TRUE
    )
  })

  it("errors informatively when no set has data", {
    mb_no_data <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      y_name = "mpg"
    )
    expect_error(gain(mb_no_data), "has no data")
  })

  it("errors when y_name is not set", {
    mb_no_y <- modelblueprint(
      model = stats::lm(mpg ~ wt, data = mtcars),
      train = mtcars
    )
    expect_error(
      gain(mb_no_y),
      "@y_name.*not set"
    )
  })
})


describe("gain.modelblueprint — title argument", {
  mb <- make_mb()

  it("accepts a custom title without error", {
    expect_no_error(gain(mb, title = "My custom title"))
  })

  it("defaults to model_display_name when title is NULL", {
    expect_no_error(gain(mb, title = NULL))
  })
})


# =============================================================================
# trapz — unit tests
# =============================================================================

describe("trapz", {
  it("integrates a constant function (area = base * height)", {
    x <- seq(0, 1, length.out = 100L)
    y <- rep(2, 100L)
    expect_equal(modelblueprint:::trapz(x, y), 2, tolerance = 1e-6)
  })

  it("integrates a linear function exactly", {
    x <- c(0, 1, 2)
    y <- c(0, 1, 2) # area under y = x from 0 to 2 = 2
    expect_equal(modelblueprint:::trapz(x, y), 2, tolerance = 1e-6)
  })

  it("approximates integral of sin(x) from 0 to pi", {
    x <- seq(0, pi, length.out = 1000L)
    y <- sin(x)
    expect_equal(modelblueprint:::trapz(x, y), 2, tolerance = 1e-4)
  })

  it("returns 0 for empty input", {
    expect_equal(modelblueprint:::trapz(numeric(0)), 0)
  })

  it("returns 0 for a single point", {
    expect_equal(modelblueprint:::trapz(1, 1), 0)
  })

  it("errors when x and y have different lengths", {
    expect_error(
      modelblueprint:::trapz(1:3, 1:4),
      "`x` and `y` must be the same length.",
      fixed = TRUE
    )
  })

  it("errors when inputs are not numeric", {
    expect_error(
      modelblueprint:::trapz("a", "b"),
      "must be numeric or complex vectors.",
      fixed = TRUE
    )
  })

  it("handles single-argument form (treats x as y)", {
    # trapz(y) with x = seq_along(y)
    result <- modelblueprint:::trapz(c(0, 1, 2))
    expect_equal(result, 2, tolerance = 1e-6)
  })
})


# =============================================================================
# compute_cumulative — unit tests
# =============================================================================

describe("compute_cumulative", {
  # Helper: build a data.table with perfect_model column without using :=
  make_cumulative_dt <- function() {
    data.table::data.table(
      obs = c(1, 0, 1, 0),
      pred = c(0.9, 0.1, 0.8, 0.2),
      exposure = 1,
      perfect_model = c(1, 0, 1, 0)
    )
  }

  it("returns a list with data, gini, and auc elements", {
    result <- modelblueprint:::compute_cumulative(
      make_cumulative_dt(),
      "pred",
      "obs",
      "exposure"
    )
    expect_true(all(c("data", "gini", "auc") %in% names(result)))
  })

  it("returned data has exactly 2 columns", {
    result <- modelblueprint:::compute_cumulative(
      make_cumulative_dt(),
      "pred",
      "obs",
      "exposure"
    )
    expect_equal(ncol(result$data), 2L)
  })

  it("cumulative exposure ends at 1", {
    result <- modelblueprint:::compute_cumulative(
      make_cumulative_dt(),
      "pred",
      "obs",
      "exposure"
    )
    expect_equal(max(result$data[[1L]]), 1, tolerance = 1e-6)
  })

  it("gini is numeric scalar", {
    result <- modelblueprint:::compute_cumulative(
      make_cumulative_dt(),
      "pred",
      "obs",
      "exposure"
    )
    expect_true(is.numeric(result$gini))
    expect_length(result$gini, 1L)
  })

  it("does not mutate the input data.table", {
    dt <- make_cumulative_dt()
    cols_before <- names(dt)
    modelblueprint:::compute_cumulative(dt, "pred", "obs", "exposure")
    expect_equal(names(dt), cols_before)
  })
})


# =============================================================================
# Public API end-to-end
# These assert on what users actually see (Gini values, ret = "data" shape,
# plot object) via the exported gain() only — no ::: access. A refactor of the
# internals that breaks user-visible behaviour must fail here.
# =============================================================================

describe("gain — public API", {
  it("a perfect model matches the baseline and beats a random model", {
    # NB: the maximum achievable Gini depends on target prevalence, so for a
    # balanced 50/50 target the "perfect" Gini is ~0.5, not ~1. The right
    # invariant is that a pred == obs model attains the perfect-model baseline
    # (element [[1]]) and clearly exceeds a random model.
    gp <- gain(make_perfect_df(), pred = "pred", obs = "obs",
               exposure = "exposure", ret = "gini")
    expect_equal(as.numeric(gp[[2L]]), as.numeric(gp[[1L]]), tolerance = 1e-6)

    gr <- gain(make_gain_df(), pred = "pred", obs = "obs",
               exposure = "exposure", ret = "gini")
    expect_lt(abs(as.numeric(gr[[2L]])), 0.2)

    expect_gt(as.numeric(gp[[2L]]), abs(as.numeric(gr[[2L]])))
  })

  it("ret = 'data' returns cumulative curves rising to 1", {
    out <- gain(make_perfect_df(), pred = "pred", obs = "obs",
                exposure = "exposure", ret = "data")
    expect_type(out, "list")
    score_curve <- out[[2L]]
    expect_s3_class(score_curve, "data.table")
    expect_equal(ncol(score_curve), 2L)
    # Both cumulative axes are fractions that end at 1.
    expect_equal(max(score_curve[[1L]]), 1, tolerance = 1e-6)
    expect_equal(max(score_curve[[2L]]), 1, tolerance = 1e-6)
  })

  it("ret = 'plot' returns a plotly object", {
    p <- gain(make_gain_df(), pred = "pred", obs = "obs",
              exposure = "exposure", ret = "plot")
    expect_s3_class(p, "plotly")
  })

  it("gain.modelblueprint produces a usable Gini end-to-end", {
    mb <- modelblueprint(
      model              = stats::glm(vs ~ wt + hp, data = mtcars,
                                      family = binomial),
      train              = mtcars,
      y_name             = "vs",
      x_original_inputs  = c("wt", "hp"),
      model_display_name = "logistic_vs"
    )
    gini <- gain(mb, ret = "gini")
    score_gini <- as.numeric(gini[[2L]])
    expect_true(is.finite(score_gini))
    # A real logistic fit should beat a coin flip on its training data.
    expect_gt(score_gini, 0)
  })
})


# =============================================================================
# Regression tests — NA handling, collisions, end-to-end Gini (1.6.1)
# =============================================================================

describe("gain — NA handling", {
  it("drops NA rows with a warning instead of truncating the curve", {
    df <- data.frame(
      obs      = c(1, NA, 0, 1, 0),
      pred     = c(0.9, 0.8, 0.2, 0.7, 0.1),
      exposure = rep(1, 5L)
    )
    expect_warning(
      result <- gain(df, pred = "pred", obs = "obs", ret = "data"),
      "Dropped 1 row"
    )
    # Both curves must be complete: no NA anywhere, ending at 1.
    for (curve in result) {
      expect_false(anyNA(curve))
      expect_equal(as.numeric(curve[nrow(curve), 1L][[1L]]), 1)
      expect_equal(as.numeric(curve[nrow(curve), 2L][[1L]]), 1)
    }
  })

  it("errors when every row has a missing value", {
    df <- data.frame(obs = c(NA, NA), pred = c(0.1, NA), exposure = 1)
    expect_error(
      gain(df, pred = "pred", obs = "obs", ret = "data"),
      "missing"
    )
  })
})

describe("gain — perfect_model column collision", {
  it("does not clobber a user score named 'perfect_model'", {
    set.seed(7L)
    df <- data.frame(
      obs           = rbinom(200L, 1L, 0.4),
      perfect_model = runif(200L),
      exposure      = 1
    )
    ginis <- gain(df, pred = "perfect_model", obs = "obs", ret = "gini")
    # ginis[[1]] is the true perfect baseline; ginis[[2]] the user's random
    # score. If the baseline overwrote the user column they would be equal.
    expect_lt(abs(ginis[[2L]]), ginis[[1L]] / 2)
  })
})

describe("gain — end-to-end Gini", {
  it("a score identical to the target reproduces the perfect-model Gini", {
    set.seed(11L)
    df <- data.frame(
      obs      = rbinom(500L, 1L, 0.3),
      exposure = rep(1, 500L)
    )
    df$pred <- df$obs
    ginis <- gain(df, pred = "pred", obs = "obs", ret = "gini")
    expect_equal(ginis[[2L]], ginis[[1L]])
  })

  it("cumulative curves are monotone non-decreasing", {
    set.seed(12L)
    df <- data.frame(
      obs      = rbinom(500L, 1L, 0.3),
      pred     = runif(500L),
      exposure = rep(1, 500L)
    )
    result <- gain(df, pred = "pred", obs = "obs", ret = "data")
    for (curve in result) {
      expect_true(all(diff(curve[[1L]]) >= 0))
      expect_true(all(diff(curve[[2L]]) >= -1e-12))
    }
  })
})

describe("gain.modelblueprint — zero exposure", {
  it("replaces zero-exposure rows with @expo_0_rep and warns", {
    train <- transform(mtcars, exposure = c(0, rep(1, 31L)))
    mb <- modelblueprint(
      model = lm(mpg ~ wt, mtcars),
      train = train,
      y_name = "mpg",
      expo_name = "exposure",
      expo_0_rep = 0.5,
      model_display_name = "m"
    )
    expect_warning(g <- gain(mb, ret = "gini"), "expo_0_rep")
    expect_true(is.finite(g[[2L]]))
  })
})

describe("plot_gain — palette beyond 12 scores", {
  it("draws more than 12 competing scores without a brewer.pal warning", {
    set.seed(13L)
    df <- data.frame(obs = rbinom(100L, 1L, 0.4), exposure = 1)
    score_cols <- paste0("s", 1:13)
    for (s in score_cols) df[[s]] <- runif(100L)
    expect_no_warning(p <- gain(df, pred = score_cols, obs = "obs"))
    expect_s3_class(p, "plotly")
  })
})
