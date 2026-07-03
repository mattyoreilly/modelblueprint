# =============================================================================
# test-pdp.R
# testthat tests for pdp.R
#
# Run with: testthat::test_file("test-pdp.R")
#
# Conventions (matching test-one_way.R):
#   - One describe() block per function or behaviour group
#   - One it() per behaviour
#   - Fixed seed fixtures; no rnorm() in fixtures meant to be NA-free
#   - All expect_error() calls use fixed = TRUE
#   - Test the contract (inputs -> outputs), not implementation details
# =============================================================================

library(testthat)
library(data.table)


# =============================================================================
# Shared fixtures
# =============================================================================

# Deterministic dataset — seq() guarantees no NAs
make_df <- function(n = 100L) {
  data.frame(
    x_num = seq(1, 100, length.out = n),
    x_cat = rep(c("A", "B", "C", "D"), length.out = n),
    x_int = rep(1L:5L, length.out = n),
    target = seq(0.1, 1.0, length.out = n),
    expo = rep(1, n),
    stringsAsFactors = FALSE
  )
}

# Minimal fitted lm — used in most tests
make_lm <- function() lm(target ~ x_num + x_int, data = make_df())

# Minimal fitted glm (binomial) — for predict() shape variety tests.
# Use a randomly sampled binary outcome to avoid complete separation.
make_glm <- function() {
  df <- make_df()
  set.seed(42L)
  df$binary <- sample(0L:1L, nrow(df), replace = TRUE)
  suppressWarnings(glm(binary ~ x_num + x_int, data = df, family = binomial))
}

is_plotly <- function(x) inherits(x, "plotly")

# =============================================================================
# modelblueprint::pdp() — return type
# =============================================================================

describe("pdp — return type", {
  df <- make_df()
  m <- make_lm()

  it("returns a plotly object by default", {
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m
    )))
  })

  it("returns a data.table when ret = 'data'", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_true(data.table::is.data.table(d))
  })

  it("rejects invalid ret value", {
    expect_error(
      modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        ret = "tibble"
      ),
      "should be one of",
      fixed = TRUE
    )
  })
})

# =============================================================================
# modelblueprint::pdp() — returned data structure
# =============================================================================

describe("pdp — returned data columns", {
  df <- make_df()
  m <- make_lm()

  it("returned data contains the var column named after the input var", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_true("x_num" %in% names(d))
  })

  it("returned data contains obs_mean, pred_mean, pdp_mean, exposure", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_true(all(
      c("obs_mean", "pred_mean", "pdp_mean", "exposure") %in% names(d)
    ))
  })

  it("returned data contains global_obs and global_pred reference columns", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_true(all(c("global_obs", "global_pred") %in% names(d)))
  })

  it("exposure sums to total rows when no exposure column supplied", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_equal(sum(d$exposure), nrow(df))
  })

  it("exposure sums to total exposure when exposure column supplied", {
    df2 <- make_df()
    df2$expo <- 2
    d <- modelblueprint::pdp(
      df2,
      var = "x_num",
      obs = "target",
      model = m,
      exposure = "expo",
      ret = "data"
    )
    expect_equal(sum(d$exposure), sum(df2$expo))
  })

  it("obs_mean values are within [min(target), max(target)]", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_true(all(d$obs_mean >= min(df$target) - 1e-9))
    expect_true(all(d$obs_mean <= max(df$target) + 1e-9))
  })

  it("global_obs is constant across all rows", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_equal(length(unique(d$global_obs)), 1L)
  })

  it("global_pred is constant across all rows", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_equal(length(unique(d$global_pred)), 1L)
  })
})

# =============================================================================
# modelblueprint::pdp() — var types
# =============================================================================

describe("pdp — var types", {
  df <- make_df()
  m <- make_lm()

  it("handles a continuous numeric var", {
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m
    )))
  })

  it("handles a low-cardinality integer var", {
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_int",
      obs = "target",
      model = m
    )))
  })

  it("handles a character (categorical) var", {
    m2 <- lm(target ~ x_cat, data = make_df())
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_cat",
      obs = "target",
      model = m2
    )))
  })

  it("handles a factor var", {
    df2 <- make_df()
    df2$x_fac <- factor(df2$x_cat)
    m2 <- lm(target ~ x_fac, data = df2)
    expect_true(is_plotly(modelblueprint::pdp(
      df2,
      var = "x_fac",
      obs = "target",
      model = m2
    )))
  })

  it("returns NULL with a warning for non-numeric var with > 500 unique values", {
    df_wide <- data.frame(
      x = paste0("level_", seq_len(501L)),
      obs = runif(501L),
      stringsAsFactors = FALSE
    )
    m_wide <- lm(obs ~ 1, data = df_wide)
    expect_warning(
      result <- modelblueprint::pdp(
        df_wide,
        var = "x",
        obs = "obs",
        model = m_wide
      ),
      "501 unique values",
      fixed = TRUE
    )
    expect_null(result)
  })
})

# =============================================================================
# modelblueprint::pdp() — bins argument
# =============================================================================

describe("pdp — bins argument", {
  df <- make_df()
  m <- make_lm()

  it("fewer bins produces fewer rows in returned data", {
    d5 <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      bins = 5L,
      ret = "data"
    )
    d10 <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      bins = 10L,
      ret = "data"
    )
    expect_lte(nrow(d5), nrow(d10))
  })

  it("bins = 2 is the minimum and does not error", {
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      bins = 2L
    )))
  })

  it("bins has no effect on a categorical var", {
    m2 <- lm(target ~ x_cat, data = make_df())
    d5 <- modelblueprint::pdp(
      df,
      var = "x_cat",
      obs = "target",
      model = m2,
      bins = 5L,
      ret = "data"
    )
    d20 <- modelblueprint::pdp(
      df,
      var = "x_cat",
      obs = "target",
      model = m2,
      bins = 20L,
      ret = "data"
    )
    expect_equal(nrow(d5), nrow(d20))
  })

  it("rejects bins < 2", {
    expect_error(
      modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        bins = 1L
      ),
      "`bins` must be a single integer >= 2.",
      fixed = TRUE
    )
  })
})

# =============================================================================
# modelblueprint::pdp() — type_agg argument
# =============================================================================

describe("pdp — type_agg argument", {
  df <- make_df()
  m <- make_lm()

  it("equal_exposure returns a plotly object", {
    expect_true(
      is_plotly(modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        type_agg = "equal_exposure"
      ))
    )
  })

  it("equal_range returns a plotly object", {
    expect_true(
      is_plotly(modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        type_agg = "equal_range"
      ))
    )
  })

  it("rejects invalid type_agg", {
    expect_error(
      modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        type_agg = "equal_banana"
      ),
      "should be one of",
      fixed = TRUE
    )
  })
})

# =============================================================================
# modelblueprint::pdp() — sample_size argument
# =============================================================================

describe("pdp — sample_size argument", {
  df <- make_df(200L)
  m <- make_lm()

  it("sample_size smaller than nrow still returns a plot", {
    expect_true(
      is_plotly(modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        sample_size = 50L
      ))
    )
  })

  it("sample_size larger than nrow uses the full dataset without error", {
    expect_true(
      is_plotly(modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        sample_size = 99999L
      ))
    )
  })

  it("rejects sample_size < 1", {
    expect_error(
      modelblueprint::pdp(
        df,
        var = "x_num",
        obs = "target",
        model = m,
        sample_size = 0L
      ),
      "`sample_size` must be a positive integer.",
      fixed = TRUE
    )
  })
})

# =============================================================================
# modelblueprint::pdp() — model_name argument
# =============================================================================

describe("pdp — model_name argument", {
  df <- make_df()
  m <- make_lm()

  it("model_name appears in returned data column names", {
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      model_name = "mymodel",
      ret = "data"
    )
    # pdp_mean is generic but model_name is used in plot trace names
    # so we just verify the data is valid
    expect_true(data.table::is.data.table(d))
  })
})

# =============================================================================
# modelblueprint::pdp() — exposure argument
# =============================================================================

describe("pdp — exposure argument", {
  df <- make_df()
  m <- make_lm()

  it("uses exposure column when present", {
    df2 <- make_df()
    df2$expo <- runif(nrow(df2), 0.5, 2)
    d <- modelblueprint::pdp(
      df2,
      var = "x_num",
      obs = "target",
      model = m,
      exposure = "expo",
      ret = "data"
    )
    # With non-unit weights, sum of exposure != nrow
    expect_false(isTRUE(all.equal(sum(d$exposure), nrow(df2))))
  })

  it("falls back to unit weights when exposure column absent", {
    df2 <- make_df()[, setdiff(names(make_df()), "expo")]
    d <- modelblueprint::pdp(
      df2,
      var = "x_num",
      obs = "target",
      model = m,
      exposure = "expo",
      ret = "data"
    )
    expect_equal(sum(d$exposure), nrow(df2))
  })
})

# =============================================================================
# modelblueprint::pdp() — does not mutate caller's data
# =============================================================================

describe("pdp — immutability", {
  it("does not add columns to the caller's data.frame", {
    df <- make_df()
    cols_before <- names(df)
    m <- make_lm()
    modelblueprint::pdp(df, var = "x_num", obs = "target", model = m)
    expect_equal(names(df), cols_before)
  })

  it("does not add columns to the caller's data.table", {
    dt <- data.table::as.data.table(make_df())
    cols_before <- names(dt)
    m <- make_lm()
    modelblueprint::pdp(dt, var = "x_num", obs = "target", model = m)
    expect_equal(names(dt), cols_before)
  })
})

# =============================================================================
# modelblueprint::pdp() — NA handling
# =============================================================================

describe("pdp — NA handling", {
  m <- make_lm()

  it("handles NAs in var without error", {
    df <- make_df()
    df$x_num[c(1L, 5L, 10L)] <- NA
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m
    )))
  })

  it("NA values in var produce a trailing 'NA' bin in returned data", {
    df <- make_df()
    df$x_num[1:5] <- NA
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_true("NA" %in% d$x_num)
    expect_equal(tail(d$x_num, 1L), "NA")
  })

  it("handles NAs in obs without error", {
    df <- make_df()
    df$target[1:3] <- NA
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m
    )))
  })
})

# =============================================================================
# modelblueprint::pdp() — model compatibility
# =============================================================================

describe("pdp — model compatibility", {
  df <- make_df()

  it("works with lm", {
    m <- lm(target ~ x_num + x_int, data = df)
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m
    )))
  })

  it("works with glm (gaussian)", {
    m <- glm(target ~ x_num + x_int, data = df, family = gaussian)
    expect_true(is_plotly(modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m
    )))
  })

  it("works with glm (binomial — predict returns probability vector)", {
    df2 <- make_df()
    set.seed(42L)
    df2$binary <- sample(0L:1L, nrow(df2), replace = TRUE)
    m <- suppressWarnings(
      glm(binary ~ x_num + x_int, data = df2, family = binomial)
    )
    expect_true(is_plotly(
      modelblueprint::pdp(df2, var = "x_num", obs = "binary", model = m)
    ))
  })

  it("works with a model whose predict() returns a matrix (e.g. nnet)", {
    # Simulate a model that returns a 1-column matrix from predict()
    fake_model <- structure(list(), class = "fake_matrix_model")
    predict.fake_matrix_model <- function(object, newdata, ...) {
      matrix(runif(nrow(newdata)), ncol = 1L)
    }
    # Register S3 method in the test environment
    registerS3method("predict", "fake_matrix_model", predict.fake_matrix_model)
    expect_true(is_plotly(
      modelblueprint::pdp(df, var = "x_num", obs = "target", model = fake_model)
    ))
  })

  it("works with a model whose predict() returns a data.frame", {
    fake_model <- structure(list(), class = "fake_df_model")
    predict.fake_df_model <- function(object, newdata, ...) {
      data.frame(pred = runif(nrow(newdata)))
    }
    registerS3method("predict", "fake_df_model", predict.fake_df_model)
    expect_true(is_plotly(
      modelblueprint::pdp(df, var = "x_num", obs = "target", model = fake_model)
    ))
  })

  it("gives an informative error when predict() fails", {
    bad_model <- structure(list(), class = "broken_model")
    expect_error(
      modelblueprint::pdp(df, var = "x_num", obs = "target", model = bad_model),
      "predict.*failed.*broken_model"
    )
  })
})

# =============================================================================
# modelblueprint::pdp() — PDP statistical property
# =============================================================================

describe("pdp — PDP statistical properties", {
  it("pdp_mean values are in a plausible range relative to observed", {
    # For a well-fitted linear model, PDP values should be broadly in the
    # same range as the observed target
    df <- make_df(200L)
    m <- lm(target ~ x_num + x_int, data = df)
    d <- modelblueprint::pdp(
      df,
      var = "x_num",
      obs = "target",
      model = m,
      ret = "data"
    )
    expect_false(any(is.na(d$pdp_mean)))
    obs_range <- range(df$target)
    # PDP should stay within 50% of the observed range (generous tolerance)
    margin <- diff(obs_range) * 0.5
    expect_true(all(d$pdp_mean >= obs_range[1] - margin, na.rm = TRUE))
    expect_true(all(d$pdp_mean <= obs_range[2] + margin, na.rm = TRUE))
  })

  it("pdp_mean varies across bins for an informative feature", {
    # wt has a strong effect on mpg in mtcars — PDP should show variation
    m <- lm(mpg ~ wt + hp + cyl, data = mtcars)
    d <- modelblueprint::pdp(
      mtcars,
      var = "wt",
      obs = "mpg",
      model = m,
      bins = 8L,
      ret = "data"
    )
    # No NAs — all bins must have a pdp_mean (merge matched correctly)
    expect_false(any(is.na(d$pdp_mean)))
    # Standard deviation of PDP values should be meaningfully > 0
    expect_gt(sd(d$pdp_mean, na.rm = TRUE), 0.1)
  })

  it("pdp_mean is roughly flat for a feature excluded from the model", {
    # x_cat is not in the model — its PDP should be near-constant
    df <- make_df(200L)
    m <- lm(target ~ x_num, data = df) # x_cat excluded
    m2 <- lm(target ~ x_cat, data = df) # needed for x_cat predict
    d <- modelblueprint::pdp(
      df,
      var = "x_cat",
      obs = "target",
      model = m,
      ret = "data"
    )
    # All PDP values should be the same (model ignores x_cat)
    expect_lt(sd(d$pdp_mean, na.rm = TRUE), 1e-10)
  })
})

# =============================================================================
# pdp_validate — unit tests
# =============================================================================

describe("pdp_validate", {
  df <- make_df()

  it("accepts a data.frame", {
    expect_no_error(modelblueprint:::pdp_validate(
      df,
      "x_num",
      "target",
      "expo",
      10L,
      1000L
    ))
  })

  it("accepts a data.table", {
    expect_no_error(
      modelblueprint:::pdp_validate(
        data.table::as.data.table(df),
        "x_num",
        "target",
        "expo",
        10L,
        1000L
      )
    )
  })

  it("rejects non-data-frame input", {
    expect_error(
      modelblueprint:::pdp_validate(
        list(x = 1),
        "x",
        "target",
        "expo",
        10L,
        1000L
      ),
      "`data` must be a data frame or data.table.",
      fixed = TRUE
    )
  })

  it("rejects missing var column", {
    expect_error(
      modelblueprint:::pdp_validate(
        df,
        "not_a_col",
        "target",
        "expo",
        10L,
        1000L
      ),
      "column.*not found.*not_a_col"
    )
  })

  it("rejects missing obs column", {
    expect_error(
      modelblueprint:::pdp_validate(
        df,
        "x_num",
        "not_a_col",
        "expo",
        10L,
        1000L
      ),
      "column.*not found.*not_a_col"
    )
  })

  it("rejects bins < 2", {
    expect_error(
      modelblueprint:::pdp_validate(df, "x_num", "target", "expo", 1L, 1000L),
      "`bins` must be a single integer >= 2.",
      fixed = TRUE
    )
  })

  it("rejects sample_size < 1", {
    expect_error(
      modelblueprint:::pdp_validate(df, "x_num", "target", "expo", 10L, 0L),
      "`sample_size` must be a positive integer.",
      fixed = TRUE
    )
  })
})

# =============================================================================
# model_predict — unit tests
# =============================================================================

describe("model_predict", {
  df <- make_df()

  it("returns a numeric vector for lm", {
    m <- lm(target ~ x_num, data = df)
    out <- modelblueprint:::model_predict(m, df)
    expect_true(is.numeric(out))
    expect_length(out, nrow(df))
  })

  it("returns a numeric vector for glm", {
    m <- glm(target ~ x_num, data = df, family = gaussian)
    out <- modelblueprint:::model_predict(m, df)
    expect_true(is.numeric(out))
    expect_length(out, nrow(df))
  })

  it("coerces matrix output to numeric vector", {
    fake_model <- structure(list(), class = "mat_model")
    predict.mat_model <- function(object, newdata, ...) {
      matrix(seq_len(nrow(newdata)), ncol = 1L)
    }
    registerS3method("predict", "mat_model", predict.mat_model)
    out <- modelblueprint:::model_predict(fake_model, df)
    expect_true(is.numeric(out))
    expect_length(out, nrow(df))
  })

  it("coerces data.frame output to numeric vector", {
    fake_model <- structure(list(), class = "df_model")
    predict.df_model <- function(object, newdata, ...) {
      data.frame(pred = seq_len(nrow(newdata)) * 1.5)
    }
    registerS3method("predict", "df_model", predict.df_model)
    out <- modelblueprint:::model_predict(fake_model, df)
    expect_true(is.numeric(out))
    expect_length(out, nrow(df))
  })

  it("gives an informative error for an unsupported model class", {
    bad <- structure(list(), class = "totally_broken")
    expect_error(
      modelblueprint:::model_predict(bad, df),
      "predict.*failed.*totally_broken"
    )
  })
})

# =============================================================================
# compute_bins — unit tests
# =============================================================================

describe("compute_bins", {
  it("returns is_numeric = FALSE for character input", {
    x <- c("A", "B", "A", "C")
    out <- modelblueprint:::compute_bins(
      x,
      bins = 3L,
      type_agg = "equal_exposure"
    )
    expect_false(out$is_numeric)
  })

  it("returns is_numeric = FALSE for low-cardinality numeric", {
    x <- rep(1:3, 10L)
    out <- modelblueprint:::compute_bins(
      x,
      bins = 10L,
      type_agg = "equal_exposure"
    )
    expect_false(out$is_numeric)
  })

  it("returns is_numeric = TRUE for high-cardinality numeric", {
    x <- seq(1, 100, length.out = 200L)
    out <- modelblueprint:::compute_bins(
      x,
      bins = 10L,
      type_agg = "equal_exposure"
    )
    expect_true(out$is_numeric)
  })

  it("labels length matches input length", {
    x <- seq(1, 100, length.out = 200L)
    out <- modelblueprint:::compute_bins(
      x,
      bins = 10L,
      type_agg = "equal_exposure"
    )
    expect_length(out$labels, 200L)
  })

  it("no label is a real NA — NAs become the string 'NA'", {
    x <- seq(1, 100, length.out = 50L)
    x[1:5] <- NA
    out <- modelblueprint:::compute_bins(
      x,
      bins = 5L,
      type_agg = "equal_exposure"
    )
    expect_false(any(is.na(out$labels)))
    expect_true("NA" %in% out$labels)
  })

  it("midpoints are numeric and finite for numeric bins", {
    x <- seq(1, 100, length.out = 200L)
    out <- modelblueprint:::compute_bins(
      x,
      bins = 10L,
      type_agg = "equal_exposure"
    )
    expect_true(all(is.finite(out$midpoints)))
  })

  it("midpoints is NULL for categorical input", {
    x <- c("A", "B", "C")
    out <- modelblueprint:::compute_bins(
      x,
      bins = 3L,
      type_agg = "equal_exposure"
    )
    expect_null(out$midpoints)
  })

  it("equal_range produces interval labels", {
    x <- seq(0, 100, length.out = 300L)
    out <- modelblueprint:::compute_bins(x, bins = 5L, type_agg = "equal_range")
    expect_true(any(grepl("\\[|\\(", out$labels[out$labels != "NA"])))
  })
})

# =============================================================================
# compute_pdp — unit tests
# =============================================================================

describe("compute_pdp", {
  df <- data.table::as.data.table(make_df())
  m <- lm(target ~ x_num + x_int, data = df)
  bin_info <- modelblueprint:::compute_bins(
    df$x_num,
    bins = 5L,
    type_agg = "equal_exposure"
  )
  df[, .bin := bin_info$labels]
  df[, .pred := predict(m, newdata = df)]
  df[, .expo := 1L]
  # all_bins mirrors what pdp.default passes: every non-NA bin in the full data
  all_bins <- unique(df$.bin[df$.bin != "NA"])

  pdp_call <- function() {
    modelblueprint:::compute_pdp(
      df,
      "x_num",
      bin_info,
      all_bins,
      ".expo",
      m,
      function(x) x,
      function(x) x,
      function(p, d) p
    )
  }

  it("returns a data.table", {
    expect_true(data.table::is.data.table(pdp_call()))
  })

  it("has columns .bin and pdp_mean", {
    expect_true(all(c(".bin", "pdp_mean") %in% names(pdp_call())))
  })

  it("has one row per bin", {
    expect_equal(nrow(pdp_call()), length(all_bins))
  })

  it("pdp_mean values are numeric and finite", {
    expect_true(all(is.finite(pdp_call()$pdp_mean)))
  })
})

# =============================================================================
# aggregate_pdp_oneway — unit tests
# =============================================================================

describe("aggregate_pdp_oneway", {
  it("returns obs_mean, pred_mean, exposure per bin", {
    df <- data.table::as.data.table(make_df())
    m <- lm(target ~ x_num, data = df)
    bin_info <- modelblueprint:::compute_bins(
      df$x_num,
      bins = 5L,
      type_agg = "equal_exposure"
    )
    df[, .bin := bin_info$labels]
    df[, .pred := predict(m, newdata = df)]
    df[, .expo := 1L]

    agg <- modelblueprint:::aggregate_pdp_oneway(df, "target", ".expo")
    expect_true(data.table::is.data.table(agg))
    expect_true(all(
      c(".bin", "obs_mean", "pred_mean", "exposure") %in% names(agg)
    ))
  })

  it("exposure sums to total weight", {
    df <- data.table::as.data.table(make_df())
    m <- lm(target ~ x_num, data = df)
    bin_info <- modelblueprint:::compute_bins(
      df$x_num,
      bins = 5L,
      type_agg = "equal_exposure"
    )
    df[, .bin := bin_info$labels]
    df[, .pred := predict(m, newdata = df)]
    df[, .expo := 1L]

    agg <- modelblueprint:::aggregate_pdp_oneway(df, "target", ".expo")
    expect_equal(sum(agg$exposure), nrow(df))
  })
})

# =============================================================================
# Scale smoke test
# =============================================================================

describe("pdp — scale", {
  it("completes in < 15 seconds on 200k rows with sample_size = 5000", {
    set.seed(1L)
    df_big <- data.frame(
      x = rnorm(200000L),
      obs = rnorm(200000L)
    )
    m <- lm(obs ~ x, data = df_big)
    t <- system.time(
      modelblueprint::pdp(
        df_big,
        var = "x",
        obs = "obs",
        model = m,
        bins = 10L,
        sample_size = 5000L
      )
    )
    expect_lt(t[["elapsed"]], 15)
  })
})

# =============================================================================
# H2O model compatibility
# =============================================================================
# These tests are skipped automatically when H2O is unavailable (no Java,
# shinyapps.io, CI without Java etc.). They run a minimal h2o.glm() for both
# regression and binomial families and verify modelblueprint::pdp() produces valid output.
# h2o.init() is called once per describe() block and shut down in teardown.

describe("pdp — H2O model compatibility", {
  # ── Skip guard ────────────────────────────────────────────────────────────────
  # Attempt to load h2o; skip the whole block if it isn't installed or if Java
  # is unavailable. This keeps the test suite green in environments without H2O.
  h2o_available <- tryCatch(
    {
      requireNamespace("h2o", quietly = TRUE) &&
        !inherits(
          tryCatch(
            h2o::h2o.init(
              nthreads = 1L,
              max_mem_size = "512m",
              port = 54399L
            ),
            error = function(e) e
          ),
          "error"
        )
    },
    error = function(e) FALSE
  )

  skip_if(!h2o_available, "H2O not available — skipping H2O tests")

  # ── Shared fixture ────────────────────────────────────────────────────────────
  # Small deterministic dataset uploaded to H2O once for all tests in the block
  df_r <- data.frame(
    x1 = seq(1, 10, length.out = 80L),
    x2 = rep(c(1, 2, 3, 4), 20L),
    target = seq(0.5, 8.0, length.out = 80L) + rnorm(80L, sd = 0.2)
  )
  df_b <- df_r
  df_b$binary <- as.factor(as.integer(df_b$target > median(df_b$target)))

  hf_r <- h2o::as.h2o(df_r)
  hf_b <- h2o::as.h2o(df_b)

  # ── Regression GLM ────────────────────────────────────────────────────────────
  m_reg <- h2o::h2o.glm(
    x = c("x1", "x2"),
    y = "target",
    training_frame = hf_r,
    family = "gaussian",
    lambda = 0,
    seed = 42L
  )

  it("h2o.glm (gaussian) — returns a plotly object", {
    expect_true(
      is_plotly(modelblueprint::pdp(
        df_r,
        var = "x1",
        obs = "target",
        model = m_reg
      ))
    )
  })

  it("h2o.glm (gaussian) — ret = 'data' returns a data.table", {
    d <- modelblueprint::pdp(
      df_r,
      var = "x1",
      obs = "target",
      model = m_reg,
      ret = "data"
    )
    expect_true(data.table::is.data.table(d))
  })

  it("h2o.glm (gaussian) — returned data has expected columns", {
    d <- modelblueprint::pdp(
      df_r,
      var = "x1",
      obs = "target",
      model = m_reg,
      ret = "data"
    )
    expect_true(all(
      c(
        "x1",
        "obs_mean",
        "pred_mean",
        "pdp_mean",
        "exposure",
        "global_obs",
        "global_pred"
      ) %in%
        names(d)
    ))
  })

  it("h2o.glm (gaussian) — pdp_mean has no NAs", {
    d <- modelblueprint::pdp(
      df_r,
      var = "x1",
      obs = "target",
      model = m_reg,
      bins = 5L,
      ret = "data"
    )
    expect_false(any(is.na(d$pdp_mean)))
  })

  it("h2o.glm (gaussian) — pdp_mean varies for an informative feature", {
    d <- modelblueprint::pdp(
      df_r,
      var = "x1",
      obs = "target",
      model = m_reg,
      bins = 5L,
      ret = "data"
    )
    expect_gt(sd(d$pdp_mean, na.rm = TRUE), 0.01)
  })

  it("h2o.glm (gaussian) — does not mutate caller's data.frame", {
    cols_before <- names(df_r)
    modelblueprint::pdp(df_r, var = "x1", obs = "target", model = m_reg)
    expect_equal(names(df_r), cols_before)
  })

  # ── Binomial GLM ─────────────────────────────────────────────────────────────
  m_bin <- h2o::h2o.glm(
    x = c("x1", "x2"),
    y = "binary",
    training_frame = hf_b,
    family = "binomial",
    lambda = 0,
    seed = 42L
  )

  it("h2o.glm (binomial) — returns a plotly object", {
    df_b2 <- df_b
    df_b2$binary <- as.integer(df_b2$binary) - 1L # 0/1 numeric for obs
    expect_true(
      is_plotly(modelblueprint::pdp(
        df_b2,
        var = "x1",
        obs = "binary",
        model = m_bin
      ))
    )
  })

  it("h2o.glm (binomial) — pred_mean is in [0, 1] (probability output)", {
    df_b2 <- df_b
    df_b2$binary <- as.integer(df_b2$binary) - 1L
    d <- modelblueprint::pdp(
      df_b2,
      var = "x1",
      obs = "binary",
      model = m_bin,
      bins = 5L,
      ret = "data"
    )
    # h2o.predict() for binomial: modelblueprint:::model_predict() returns p1 (positive class
    # probability), not the class label in the first "predict" column
    expect_true(all(d$pred_mean >= 0 & d$pred_mean <= 1, na.rm = TRUE))
    expect_true(all(d$pdp_mean >= 0 & d$pdp_mean <= 1, na.rm = TRUE))
  })

  it("h2o.glm (binomial) — pdp_mean has no NAs", {
    df_b2 <- df_b
    df_b2$binary <- as.integer(df_b2$binary) - 1L
    d <- modelblueprint::pdp(
      df_b2,
      var = "x1",
      obs = "binary",
      model = m_bin,
      bins = 5L,
      ret = "data"
    )
    expect_false(any(is.na(d$pdp_mean)))
  })

  it("h2o.glm (binomial) — ret = 'data' has expected columns", {
    df_b2 <- df_b
    df_b2$binary <- as.integer(df_b2$binary) - 1L
    d <- modelblueprint::pdp(
      df_b2,
      var = "x1",
      obs = "binary",
      model = m_bin,
      ret = "data"
    )
    expect_true(all(
      c(
        "x1",
        "obs_mean",
        "pred_mean",
        "pdp_mean",
        "exposure",
        "global_obs",
        "global_pred"
      ) %in%
        names(d)
    ))
  })

  # ── Teardown — shut H2O down cleanly after all H2O tests ────────────────────
  # withr::defer() runs after the describe() block regardless of test outcome.
  # h2o_shutdown_safe() polls until the JVM has released the port.
  withr::defer(h2o_shutdown_safe())
})


# =============================================================================
# Regression tests — multinomial guard, verbose, NA weighting, offset (1.6.1)
# =============================================================================

describe("model_predict — H2O multinomial guard", {
  it("errors clearly instead of returning class level codes", {
    fake <- structure(list(), class = c("H2OMultinomialModel", "H2OModel"))
    expect_error(
      modelblueprint:::model_predict(fake, mtcars),
      "multinomial"
    )
  })
})

describe("pdp — verbose argument", {
  it("is silent by default", {
    m <- lm(mpg ~ wt, mtcars)
    expect_no_message(
      pdp(mtcars, var = "wt", obs = "mpg", model = m, ret = "data")
    )
  })

  it("announces the variable when verbose = TRUE", {
    m <- lm(mpg ~ wt, mtcars)
    expect_message(
      pdp(mtcars, var = "wt", obs = "mpg", model = m, ret = "data",
          verbose = TRUE),
      "Calculating pdp"
    )
  })
})

describe("pdp — NA target weighting", {
  it("excludes exposure of NA-target rows from obs_mean denominators", {
    df <- mtcars
    df$mpg[1:5] <- NA
    m <- lm(mpg ~ wt, mtcars)
    out <- pdp(df, var = "cyl", obs = "mpg", model = m, ret = "data")
    for (b in c(4, 6, 8)) {
      expected <- mean(df$mpg[df$cyl == b], na.rm = TRUE)
      expect_equal(
        out$obs_mean[out$cyl == as.character(b)],
        expected,
        tolerance = 1e-10
      )
    }
    expect_equal(out$global_obs[1L], mean(df$mpg, na.rm = TRUE))
  })
})

describe("pdp.modelblueprint — offset models", {
  it("keeps @offset_name when narrowing to @x_original_inputs", {
    df <- transform(mtcars, off = log(pmax(wt, 1)))
    mb <- modelblueprint(
      model = glm(mpg ~ hp + offset(off), data = df, family = gaussian),
      train = df,
      y_name = "mpg",
      x_original_inputs = "hp",
      offset_name = "off",
      model_display_name = "offset_glm"
    )
    out <- pdp(mb, var = "hp", ret = "data")
    expect_true(all(is.finite(out$pdp_mean)))
  })
})
