# =============================================================================
# test-one_way.R
# testthat tests for one_way.R
#
# Run with: testthat::test_file("test-one_way.R")
# or:       devtools::test()
#
# Organised following Hadley's convention in testthat:
#   - One describe() block per function
#   - One it() / test_that() per behaviour
#   - Fixtures defined once at the top of each describe() block
#   - Test the contract (inputs → outputs), not the implementation
# =============================================================================

library(testthat)
library(data.table)

# Source the file under test — adjust path if running from a different wd

# =============================================================================
# Shared fixtures
# =============================================================================

# Small deterministic dataset — used by most tests
make_df <- function(n = 200L, seed = 42L) {
  set.seed(seed)
  data.frame(
    x_num = rnorm(n, mean = 50, sd = 15), # continuous numeric
    x_cat = sample(c("A", "B", "C"), n, TRUE), # categorical
    x_int = sample(1L:5L, n, TRUE), # low-cardinality integer
    obs = runif(n), # target / observed
    obs2 = runif(n, 0.1, 0.9), # second observed column
    expo = runif(n, 0.5, 2), # exposure weights
    grp = sample(c("X", "Y"), n, TRUE), # split variable
    stringsAsFactors = FALSE
  )
}

# Large dataset for scale tests
make_large_df <- function(n = 1e6L, seed = 1L) {
  set.seed(seed)
  data.frame(
    x = rnorm(n),
    obs = rnorm(n),
    stringsAsFactors = FALSE
  )
}

is_plotly <- function(x) inherits(x, "plotly")

# =============================================================================
# validate_inputs / assert_col_exists
# =============================================================================

describe("validate_inputs", {
  df <- make_df()

  it("accepts a data.frame", {
    expect_no_error(modelblueprint:::validate_inputs(
      df,
      "x_num",
      "obs",
      "expo",
      NA,
      10L
    ))
  })

  it("accepts a data.table", {
    expect_no_error(
      modelblueprint:::validate_inputs(
        data.table::as.data.table(df),
        "x_num",
        "obs",
        "expo",
        NA,
        10L
      )
    )
  })

  it("rejects non-data-frame input", {
    expect_error(
      modelblueprint:::validate_inputs(
        list(x = 1),
        "x",
        "obs",
        "expo",
        NA,
        10L
      ),
      "`data` must be a data frame or data.table",
      fixed = TRUE
    )
  })

  it("rejects a missing var column", {
    expect_error(
      modelblueprint:::validate_inputs(df, "not_a_col", "obs", "expo", NA, 10L),
      "column.*not found.*not_a_col"
    )
  })

  it("rejects a missing obs column", {
    expect_error(
      modelblueprint:::validate_inputs(
        df,
        "x_num",
        "not_a_col",
        "expo",
        NA,
        10L
      ),
      "column.*not found.*not_a_col"
    )
  })

  it("rejects a missing split column when split is not NA", {
    expect_error(
      modelblueprint:::validate_inputs(
        df,
        "x_num",
        "obs",
        "expo",
        "not_a_col",
        10L
      ),
      "column.*not found.*not_a_col"
    )
  })

  it("accepts split = NA without checking split column existence", {
    expect_no_error(
      modelblueprint:::validate_inputs(df, "x_num", "obs", "expo", NA, 10L)
    )
  })

  it("rejects bins < 2", {
    expect_error(
      modelblueprint:::validate_inputs(df, "x_num", "obs", "expo", NA, 1L),
      "`bins` must be a single integer >= 2.",
      fixed = TRUE
    )
  })

  it("rejects non-numeric bins", {
    expect_error(
      modelblueprint:::validate_inputs(df, "x_num", "obs", "expo", NA, "ten"),
      "`bins` must be a single integer >= 2.",
      fixed = TRUE
    )
  })

  it("rejects vector bins", {
    expect_error(
      modelblueprint:::validate_inputs(
        df,
        "x_num",
        "obs",
        "expo",
        NA,
        c(10L, 20L)
      ),
      "`bins` must be a single integer >= 2.",
      fixed = TRUE
    )
  })

  it("names all missing obs columns in the error message", {
    expect_error(
      modelblueprint:::validate_inputs(
        df,
        "x_num",
        c("bad1", "bad2"),
        "expo",
        NA,
        10L
      ),
      "bad1.*bad2"
    )
  })
})

# =============================================================================
# one_way — argument contracts
# =============================================================================

describe("one_way — return type", {
  df <- make_df()

  it("returns a plotly object by default", {
    p <- modelblueprint::one_way(df, var = "x_num", obs = "obs")
    expect_true(is_plotly(p))
  })

  it("returns a data.table when ret = 'data'", {
    d <- modelblueprint::one_way(df, var = "x_num", obs = "obs", ret = "data")
    expect_true(data.table::is.data.table(d))
  })

  it("returned data has expected columns: x, split, obs, exposure", {
    d <- modelblueprint::one_way(df, var = "x_num", obs = "obs", ret = "data")
    expect_true(all(c("x_num", "split", "obs", "exposure") %in% names(d)))
  })
})

describe("one_way — var types", {
  df <- make_df()

  it("handles a continuous numeric var", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs"
    )))
  })

  it("handles a low-cardinality integer var (no binning)", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_int",
      obs = "obs"
    )))
  })

  it("handles a character var", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_cat",
      obs = "obs"
    )))
  })

  it("handles a factor var", {
    df2 <- df
    df2$fac <- factor(df2$x_cat)
    expect_true(is_plotly(modelblueprint::one_way(
      df2,
      var = "fac",
      obs = "obs"
    )))
  })
})

describe("one_way — obs argument", {
  df <- make_df()

  it("accepts a single obs column", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs"
    )))
  })

  it("accepts multiple obs columns", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = c("obs", "obs2")
    )))
  })

  it("returns data with both obs columns when ret = 'data'", {
    d <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = c("obs", "obs2"),
      ret = "data"
    )
    expect_true(all(c("obs", "obs2") %in% names(d)))
  })
})

describe("one_way — exposure argument", {
  df <- make_df()

  it("uses the exposure column when present", {
    d_expo <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      exposure = "expo",
      ret = "data"
    )
    expect_true(is.numeric(d_expo$exposure))
    expect_true(all(d_expo$exposure > 0))
  })

  it("falls back to unit weights when exposure column is missing", {
    df2 <- df[, setdiff(names(df), "expo")]
    d <- modelblueprint::one_way(
      df2,
      var = "x_num",
      obs = "obs",
      exposure = "expo",
      ret = "data"
    )
    # With unit weights, total exposure = n rows per bin
    expect_true(all(d$exposure >= 1))
  })

  it("falls back to unit weights for the default 'vec_of_ones' sentinel", {
    d <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      exposure = "vec_of_ones",
      ret = "data"
    )
    expect_true(data.table::is.data.table(d))
  })

  it("does not mutate the caller's data frame", {
    df_orig <- df
    modelblueprint::one_way(df, var = "x_num", obs = "obs", exposure = "expo")
    expect_equal(names(df), names(df_orig))
    expect_equal(nrow(df), nrow(df_orig))
  })
})

describe("one_way — split argument", {
  df <- make_df()

  it("produces a split plot when split is supplied", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      split = "grp"
    )))
  })

  it("split data has one row per (x-bin × split group)", {
    d <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      split = "grp",
      ret = "data"
    )
    expect_true("split" %in% names(d))
    expect_true(data.table::uniqueN(d$split) > 1L)
  })

  it("high-cardinality numeric split is auto-binned into groups", {
    df2 <- df
    df2$split_num <- rnorm(nrow(df2)) # continuous — > 20 unique values
    d <- modelblueprint::one_way(
      df2,
      var = "x_num",
      obs = "obs",
      split = "split_num",
      ret = "data"
    )
    # Should produce interval-labelled groups, not 200 unique values
    expect_lte(data.table::uniqueN(d$split), 15L)
  })

  it("NA split is treated as no split", {
    p_no_split <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      split = NA
    )
    p_with_split <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      split = "grp"
    )
    expect_true(is_plotly(p_no_split))
    expect_true(is_plotly(p_with_split))
  })
})

describe("one_way — bins argument", {
  df <- make_df()

  it("fewer bins produces fewer x levels", {
    d10 <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      bins = 10L,
      ret = "data"
    )
    d20 <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      bins = 20L,
      ret = "data"
    )
    expect_lte(nrow(d10), nrow(d20))
  })

  it("bins = 2 is the minimum and does not error", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      bins = 2L
    )))
  })

  it("large bins value still returns a plot", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      bins = 100L
    )))
  })

  it("bins has no effect on a categorical var (no binning applied)", {
    d5 <- modelblueprint::one_way(
      df,
      var = "x_cat",
      obs = "obs",
      bins = 5L,
      ret = "data"
    )
    d50 <- modelblueprint::one_way(
      df,
      var = "x_cat",
      obs = "obs",
      bins = 50L,
      ret = "data"
    )
    expect_equal(nrow(d5), nrow(d50))
  })
})

describe("one_way — type_agg argument", {
  df <- make_df()

  it("equal_exposure returns a plotly object", {
    expect_true(
      is_plotly(modelblueprint::one_way(
        df,
        var = "x_num",
        obs = "obs",
        type_agg = "equal_exposure"
      ))
    )
  })

  it("equal_range returns a plotly object", {
    expect_true(
      is_plotly(modelblueprint::one_way(
        df,
        var = "x_num",
        obs = "obs",
        type_agg = "equal_range"
      ))
    )
  })

  it("rejects an invalid type_agg value", {
    expect_error(
      modelblueprint::one_way(
        df,
        var = "x_num",
        obs = "obs",
        type_agg = "equal_banana"
      ),
      "should be one of",
      fixed = TRUE
    )
  })

  it("equal_exposure bins have more balanced row counts than equal_range", {
    d_ee <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      bins = 10L,
      type_agg = "equal_exposure",
      ret = "data"
    )
    d_er <- modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      bins = 10L,
      type_agg = "equal_range",
      ret = "data"
    )
    # Equal-exposure should have lower CV of bin exposures
    cv <- function(x) sd(x) / mean(x)
    expect_lt(cv(d_ee$exposure), cv(d_er$exposure))
  })
})

describe("one_way — ret argument", {
  df <- make_df()

  it("ret = 'plot' returns plotly", {
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs",
      ret = "plot"
    )))
  })

  it("ret = 'data' returns data.table", {
    expect_true(
      data.table::is.data.table(modelblueprint::one_way(
        df,
        var = "x_num",
        obs = "obs",
        ret = "data"
      ))
    )
  })

  it("rejects invalid ret value", {
    expect_error(
      modelblueprint::one_way(df, var = "x_num", obs = "obs", ret = "tibble"),
      "should be one of",
      fixed = TRUE
    )
  })
})

# =============================================================================
# one_way — edge cases
# =============================================================================

describe("one_way — NA handling", {
  it("handles NAs in var without error", {
    df <- make_df()
    df$x_num[sample(nrow(df), 20L)] <- NA
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs"
    )))
  })

  it("NA values appear as a trailing 'NA' category in aggregated data", {
    df <- make_df()
    df$x_cat[1:5] <- NA
    d <- modelblueprint::one_way(df, var = "x_cat", obs = "obs", ret = "data")
    expect_true("NA" %in% d$x_cat)
    # NA must be last
    expect_equal(tail(d$x_cat, 1L), "NA")
  })

  it("handles NAs in obs column (computes mean over non-NA rows)", {
    df <- make_df()
    df$obs[sample(nrow(df), 10L)] <- NA
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "obs"
    )))
  })

  it("handles NAs in exposure column (treated as zero weight)", {
    df <- make_df()
    df$expo[1:5] <- NA
    # Should not error — na.rm = TRUE in aggregation
    expect_true(is_plotly(
      modelblueprint::one_way(df, var = "x_num", obs = "obs", exposure = "expo")
    ))
  })
})

describe("one_way — cardinality guards", {
  it("returns NULL with a warning for non-numeric var with > 2000 unique values", {
    df_wide <- data.frame(
      x = paste0("level_", seq_len(2001L)),
      obs = runif(2001L),
      stringsAsFactors = FALSE
    )
    expect_warning(
      result <- modelblueprint::one_way(df_wide, var = "x", obs = "obs"),
      "2001 unique values"
    )
    expect_null(result)
  })

  it("does NOT warn or return NULL for numeric var with > 2000 unique values", {
    df_big <- data.frame(x = rnorm(3000L), obs = runif(3000L))
    expect_no_warning(
      result <- modelblueprint::one_way(
        df_big,
        var = "x",
        obs = "obs",
        bins = 20L
      )
    )
    expect_true(is_plotly(result))
  })
})

describe("one_way — does not mutate caller data", {
  it("leaves the original data.frame unchanged", {
    df <- make_df()
    cols_before <- names(df)
    nrow_before <- nrow(df)
    modelblueprint::one_way(df, var = "x_num", obs = "obs", exposure = "expo")
    expect_equal(names(df), cols_before)
    expect_equal(nrow(df), nrow_before)
  })

  it("leaves the original data.table unchanged", {
    dt <- data.table::as.data.table(make_df())
    cols_before <- names(dt)
    modelblueprint::one_way(dt, var = "x_num", obs = "obs", exposure = "expo")
    expect_equal(names(dt), cols_before)
  })
})

describe("one_way — column name collision resistance", {
  it("works when the var column is named 'var'", {
    df <- make_df()
    df$var <- df$x_num
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "var",
      obs = "obs"
    )))
  })

  it("works when the obs column is named 'x'", {
    df <- make_df()
    df$x <- df$obs
    expect_true(is_plotly(modelblueprint::one_way(
      df,
      var = "x_num",
      obs = "x"
    )))
  })

  it("works when an obs column is named 'exposure'", {
    df <- make_df()
    df$exposure <- df$obs
    expect_true(is_plotly(
      modelblueprint::one_way(
        df,
        var = "x_num",
        obs = "exposure",
        exposure = "expo"
      )
    ))
  })

  it("works when var and split columns have the same name as obs", {
    df <- make_df()
    df$split <- df$grp
    expect_true(is_plotly(
      modelblueprint::one_way(df, var = "x_num", obs = "obs", split = "split")
    ))
  })
})

# =============================================================================
# aggregate_one_way — unit tests
# =============================================================================

describe("aggregate_one_way", {
  dt <- data.table::as.data.table(make_df())
  dt[, .expo := 1L] # unit weights

  it("returns a data.table", {
    agg <- modelblueprint:::aggregate_one_way(
      dt,
      "x_num",
      "obs",
      ".expo",
      NA,
      10L,
      "equal_exposure"
    )
    expect_true(data.table::is.data.table(agg))
  })

  it("has columns: x, split, obs, exposure", {
    agg <- modelblueprint:::aggregate_one_way(
      dt,
      "x_num",
      "obs",
      ".expo",
      NA,
      10L,
      "equal_exposure"
    )
    expect_true(all(c(".x_bin", "split", "obs", "exposure") %in% names(agg)))
  })

  it("exposure column sums to total weight of input", {
    agg <- modelblueprint:::aggregate_one_way(
      dt,
      "x_num",
      "obs",
      ".expo",
      NA,
      10L,
      "equal_exposure"
    )
    expect_equal(sum(agg$exposure), nrow(dt))
  })

  it("weighted mean is within [min(obs), max(obs)]", {
    agg <- modelblueprint:::aggregate_one_way(
      dt,
      "x_num",
      "obs",
      ".expo",
      NA,
      10L,
      "equal_exposure"
    )
    expect_true(all(agg$obs >= min(dt$obs, na.rm = TRUE) - 1e-9))
    expect_true(all(agg$obs <= max(dt$obs, na.rm = TRUE) + 1e-9))
  })

  it("x-axis is ordered numerically for interval labels", {
    # Explicitly remove any NAs so the sentinel "NA" row can't appear and
    # contaminate the ordering check. seq() guarantees no NAs.
    dt_clean <- data.table::data.table(
      x_num = seq(1, 100, length.out = 200L),
      obs = seq(0, 1, length.out = 200L)
    )
    dt_clean[, .expo := 1L]
    agg <- modelblueprint:::aggregate_one_way(
      dt_clean,
      "x_num",
      "obs",
      ".expo",
      NA,
      10L,
      "equal_exposure"
    )
    # Drop any NA sentinel row — this test is only about numeric interval order
    bins <- unique(agg$.x_bin[agg$.x_bin != "NA"])
    ordered <- modelblueprint:::smart_level_order(bins)
    expect_equal(bins, ordered)
  })

  it("real NA values in var become the string 'NA' in .x_bin, not a real NA", {
    set.seed(42L)
    dt_na <- data.table::as.data.table(
      data.frame(x_num = c(NA_real_, rnorm(199L, 50, 15)), obs = runif(200L))
    )
    dt_na[, .expo := 1L]
    agg <- modelblueprint:::aggregate_one_way(
      dt_na,
      "x_num",
      "obs",
      ".expo",
      NA,
      10L,
      "equal_exposure"
    )
    # Must be the string "NA", not a real NA
    expect_true("NA" %in% agg$.x_bin)
    expect_false(any(is.na(agg$.x_bin)))
    # String "NA" must be the last row
    expect_equal(tail(agg$.x_bin, 1L), "NA")
  })

  it("split = NA produces a single '__none__' split group", {
    agg <- modelblueprint:::aggregate_one_way(
      dt,
      "x_num",
      "obs",
      ".expo",
      NA,
      10L,
      "equal_exposure"
    )
    expect_equal(unique(agg$split), "__none__")
  })

  it("split column produces multiple groups", {
    dt2 <- data.table::copy(dt)
    agg <- modelblueprint:::aggregate_one_way(
      dt2,
      "x_num",
      "obs",
      ".expo",
      "grp",
      10L,
      "equal_exposure"
    )
    expect_gte(data.table::uniqueN(agg$split), 2L)
  })
})

# =============================================================================
# apply_binning — unit tests
# =============================================================================

describe("apply_binning", {
  it("does not bin a character column", {
    dt <- data.table::data.table(var = c("A", "B", "A", "C"), .w = 1L)
    out <- modelblueprint:::apply_binning(
      dt,
      bins = 2L,
      type_agg = "equal_exposure"
    )
    expect_equal(out$var, c("A", "B", "A", "C"))
  })

  it("does not bin a low-cardinality numeric column (unique values <= bins)", {
    # 5 unique values, bins = 10 — uniqueN(5) <= 10 so binning is skipped
    dt <- data.table::data.table(var = rep(1:5, 10L), .w = 1L)
    out <- modelblueprint:::apply_binning(
      dt,
      bins = 10L,
      type_agg = "equal_exposure"
    )
    expect_true(is.numeric(out$var) || all(nchar(out$var) <= 2L))
  })

  it("bins a numeric column when unique values > bins", {
    # 32 unique values, bins = 5 — should bin (this was the mtcars$wt bug)
    set.seed(1L)
    dt <- data.table::data.table(var = seq(1, 100, length.out = 32L), .w = 1L)
    out <- modelblueprint:::apply_binning(
      dt,
      bins = 5L,
      type_agg = "equal_exposure"
    )
    expect_true(any(grepl("\\[|\\(", out$var, perl = TRUE)))
  })

  it("bins a high-cardinality numeric column into interval strings", {
    set.seed(1L)
    dt <- data.table::data.table(var = rnorm(500L), .w = 1L)
    out <- modelblueprint:::apply_binning(
      dt,
      bins = 10L,
      type_agg = "equal_exposure"
    )
    # Interval labels contain "[" or "("
    expect_true(any(grepl("\\[|\\(", out$var, perl = TRUE)))
  })

  it("preserves NA positions after binning", {
    set.seed(1L)
    v <- c(NA, rnorm(199L))
    dt <- data.table::data.table(var = v, .w = 1L)
    out <- modelblueprint:::apply_binning(
      dt,
      bins = 10L,
      type_agg = "equal_exposure"
    )
    expect_true(is.na(out$var[1L]))
  })

  it("equal_range produces approximately equal-width intervals", {
    set.seed(1L)
    dt <- data.table::data.table(var = runif(500L, 0, 100), .w = 1L)
    out <- modelblueprint:::apply_binning(
      dt,
      bins = 5L,
      type_agg = "equal_range"
    )
    lvls <- unique(na.omit(out$var))
    # All interval labels should contain numbers parseable from the same range
    expect_true(length(lvls) <= 6L)
  })
})

# =============================================================================
# bin_equal_exposure — unit tests
# =============================================================================

describe("bin_equal_exposure", {
  it("returns a factor", {
    x <- sort(rnorm(100L))
    expect_true(is.factor(modelblueprint:::bin_equal_exposure(x, 10L)))
  })

  it("number of levels <= bins", {
    x <- sort(rnorm(100L))
    b <- modelblueprint:::bin_equal_exposure(x, 10L)
    expect_lte(nlevels(b), 10L)
  })

  it("every element is assigned a bin (no NAs)", {
    x <- sort(rnorm(200L)) # bin_equal_exposure contract: input must be sorted
    b <- modelblueprint:::bin_equal_exposure(x, 10L)
    expect_true(all(!is.na(b)))
  })

  it("bins are roughly equal in size", {
    x <- sort(rnorm(1000L))
    b <- modelblueprint:::bin_equal_exposure(x, 10L)
    counts <- table(b)
    # No bin should be more than 3× the size of the smallest
    expect_lt(max(counts) / min(counts), 3)
  })
})

# =============================================================================
# bin_equal_range — unit tests
# =============================================================================

describe("bin_equal_range", {
  it("returns a factor", {
    x <- rnorm(100L)
    expect_true(is.factor(modelblueprint:::bin_equal_range(x, 10L)))
  })

  it("number of levels <= bins", {
    x <- rnorm(100L)
    expect_lte(nlevels(modelblueprint:::bin_equal_range(x, 10L)), 10L)
  })

  it("handles a constant vector without error", {
    # All same value — range = 0, spread = 0
    x <- rep(5, 50L)
    expect_no_error(modelblueprint:::bin_equal_range(x, 5L))
  })
})

# =============================================================================
# smart_level_order — unit tests
# =============================================================================

describe("smart_level_order", {
  it("returns empty vector for empty input", {
    expect_equal(
      modelblueprint:::smart_level_order(character(0L)),
      character(0L)
    )
  })

  it("sorts interval labels numerically not lexicographically", {
    labels <- c("[10,20)", "[2,10)", "[1,2)")
    expected <- c("[1,2)", "[2,10)", "[10,20)")
    expect_equal(modelblueprint:::smart_level_order(labels), expected)
  })

  it("places NA label last", {
    labels <- c("B", "A", "NA", "[1,5)")
    result <- modelblueprint:::smart_level_order(labels)
    expect_equal(tail(result, 1L), "NA")
  })

  it("sorts categorical labels alphabetically after numerics", {
    labels <- c("C", "A", "[1,5)", "B")
    result <- modelblueprint:::smart_level_order(labels)
    expect_equal(result, c("[1,5)", "A", "B", "C"))
  })

  it("handles negative numeric labels correctly", {
    labels <- c("[-10,-5)", "[-5,0)", "[0,5)")
    expect_equal(
      modelblueprint:::smart_level_order(labels),
      c("[-10,-5)", "[-5,0)", "[0,5)")
    )
  })

  it("handles purely categorical input", {
    labels <- c("Medium", "High", "Low")
    expect_equal(
      modelblueprint:::smart_level_order(labels),
      c("High", "Low", "Medium")
    )
  })
})

# =============================================================================
# hex_to_rgba — unit tests
# =============================================================================

describe("hex_to_rgba", {
  it("converts a hex colour to rgba string", {
    result <- modelblueprint:::hex_to_rgba("#2563eb", 0.5)
    expect_true(grepl("^rgba\\(", result))
  })

  it("alpha = 1 produces fully opaque rgba", {
    result <- modelblueprint:::hex_to_rgba("#000000", 1)
    expect_equal(result, "rgba(0,0,0,1.00)")
  })

  it("alpha = 0 produces fully transparent rgba", {
    result <- modelblueprint:::hex_to_rgba("#ffffff", 0)
    expect_equal(result, "rgba(255,255,255,0.00)")
  })

  it("handles shorthand and named colours", {
    expect_no_error(modelblueprint:::hex_to_rgba("red", 0.5))
    expect_no_error(modelblueprint:::hex_to_rgba("blue", 0.3))
  })
})

# =============================================================================
# make_palette — unit tests
# =============================================================================

describe("make_palette", {
  it("returns a single colour for n = 1", {
    result <- modelblueprint:::make_palette(1L)
    expect_length(result, 1L)
  })

  it("returns n colours for n >= 3", {
    for (n in 3:12) {
      expect_length(modelblueprint:::make_palette(n), n)
    }
  })

  it("returns 2 colours for n = 2", {
    expect_length(modelblueprint:::make_palette(2L), 2L)
  })

  it("all returned values are valid hex colours", {
    cols <- modelblueprint:::make_palette(6L)
    expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", cols)))
  })
})

# =============================================================================
# sig_dig — unit tests
# =============================================================================

describe("sig_dig", {
  it("returns a character vector", {
    expect_type(modelblueprint:::sig_dig(3.14159), "character")
  })

  it("rounds to the specified number of significant digits", {
    result <- as.numeric(modelblueprint:::sig_dig(123456.789, n = 4L))
    expect_equal(result, 123500, tolerance = 1)
  })

  it("handles zero", {
    expect_no_error(modelblueprint:::sig_dig(0, n = 7L))
  })

  it("handles negative numbers", {
    expect_no_error(modelblueprint:::sig_dig(-42.5, n = 3L))
  })

  it("handles NA input", {
    result <- modelblueprint:::sig_dig(NA_real_, n = 7L)
    expect_true(is.na(suppressWarnings(as.numeric(result))))
  })

  it("vectorises correctly", {
    result <- modelblueprint:::sig_dig(c(1.111, 2.222, 3.333), n = 3L)
    expect_length(result, 3L)
  })
})

# =============================================================================
# Scale / performance smoke test
# =============================================================================

describe("one_way — scale", {
  it("completes in < 10 seconds on 1M rows", {
    df_big <- make_large_df(1e6L)
    t <- system.time(
      modelblueprint::one_way(df_big, var = "x", obs = "obs", bins = 25L)
    )
    expect_lt(t[["elapsed"]], 10)
  })
})

# =============================================================================
# one_way — NSE (bare names)
# =============================================================================
# one_way() now accepts bare (unquoted) column names as well as strings.
# These tests verify parity: bare-name and string calls must return identical
# output, and combinations (bare var + string obs, etc.) must also work.

describe("one_way — bare name arguments (NSE)", {
  df <- make_df()  # cols: x_num, x_cat, x_int, obs, obs2, expo, grp

  it("bare var produces same result as string var", {
    d_bare <- one_way(df, x_num, obs = "obs", exposure = "expo", ret = "data")
    d_str  <- one_way(df, var = "x_num", obs = "obs", exposure = "expo",
                      ret = "data")
    expect_equal(d_bare, d_str)
  })

  it("bare obs produces same result as string obs", {
    d_bare <- one_way(df, var = "x_num", obs, exposure = "expo", ret = "data")
    d_str  <- one_way(df, var = "x_num", obs = "obs", exposure = "expo",
                      ret = "data")
    expect_equal(d_bare, d_str)
  })

  it("c(bare, bare) obs produces same result as c(str, str)", {
    d_bare <- one_way(df, x_num, c(obs, obs2), exposure = "expo", ret = "data")
    d_str  <- one_way(df, var = "x_num", obs = c("obs", "obs2"),
                      exposure = "expo", ret = "data")
    expect_equal(d_bare, d_str)
  })

  it("bare split produces same result as string split", {
    d_bare <- one_way(df, x_num, "obs", exposure = "expo", split = grp,
                      ret = "data")
    d_str  <- one_way(df, var = "x_num", obs = "obs", exposure = "expo",
                      split = "grp", ret = "data")
    expect_equal(d_bare, d_str)
  })

  it("NULL split is equivalent to NA split", {
    d_null <- one_way(df, "x_num", "obs", exposure = "expo", split = NULL,
                      ret = "data")
    d_na   <- one_way(df, "x_num", "obs", exposure = "expo", split = NA,
                      ret = "data")
    expect_equal(d_null, d_na)
  })

  it("programmatic string variable still works (no NSE confusion)", {
    col <- "x_num"
    d_prog <- one_way(df, var = col, obs = "obs", exposure = "expo",
                      ret = "data")
    d_str  <- one_way(df, var = "x_num", obs = "obs", exposure = "expo",
                      ret = "data")
    expect_equal(d_prog, d_str)
  })
})
