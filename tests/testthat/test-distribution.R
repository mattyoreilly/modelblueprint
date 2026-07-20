# =============================================================================
# test-distribution.R
# testthat tests for distribution.R
# =============================================================================

library(testthat)
library(data.table)

make_df <- function(n = 200L, seed = 42L) {
  set.seed(seed)
  data.frame(
    target = runif(n),
    expo = runif(n, 0.5, 2),
    grp = sample(c("X", "Y"), n, TRUE),
    stringsAsFactors = FALSE
  )
}

is_plotly <- function(x) inherits(x, "plotly")

describe("distribution", {
  df <- make_df()

  it("returns a plotly object by default", {
    expect_true(is_plotly(distribution(df, target, exposure = expo, bins = 10L)))
  })

  it("accepts strings and bare names equivalently", {
    a <- distribution(df, target, exposure = expo, ret = "data", bins = 10L)
    b <- distribution(df, "target", exposure = "expo", ret = "data", bins = 10L)
    expect_identical(a, b)
  })

  it("returns aggregated data with ret = 'data'", {
    agg <- distribution(df, target, exposure = expo, ret = "data", bins = 10L)
    expect_s3_class(agg, "data.table")
    expect_true(all(c("target", "split", "exposure") %in% names(agg)))
    expect_lte(nrow(agg), 10L)
    # Total exposure is conserved across bins
    expect_equal(sum(agg$exposure), sum(df$expo))
  })

  it("falls back to unit weights when exposure column is absent", {
    agg <- distribution(df, target, ret = "data", bins = 10L)
    expect_equal(sum(agg$exposure), nrow(df))
  })

  it("supports a split variable", {
    p <- distribution(df, target, exposure = expo, split = grp, bins = 10L)
    expect_true(is_plotly(p))
    agg <- distribution(
      df,
      target,
      exposure = expo,
      split = grp,
      ret = "data",
      bins = 10L
    )
    expect_setequal(unique(agg$split), c("X", "Y"))
  })

  it("puts NA targets in a trailing 'NA' category", {
    df_na <- df
    df_na$target[1:5] <- NA
    agg <- distribution(df_na, target, exposure = expo, ret = "data", bins = 10L)
    expect_true("NA" %in% agg$target)
  })

  it("handles categorical targets", {
    df$target_cat <- sample(c("low", "mid", "high"), nrow(df), TRUE)
    agg <- distribution(df, target_cat, exposure = expo, ret = "data")
    expect_setequal(agg$target_cat, c("low", "mid", "high"))
  })

  it("errors on a missing target column", {
    expect_error(distribution(df, "nope"), "not found")
  })

  it("does not mutate the caller's data", {
    dt <- data.table::as.data.table(df)
    before <- data.table::copy(dt)
    invisible(distribution(dt, target, exposure = expo, bins = 10L))
    expect_identical(dt, before)
  })
})

describe("distribution.modelblueprint", {
  it("dispatches on a modelblueprint and uses its target", {
    mb <- mb_glm_regression()
    p <- distribution(mb, bins = 10L)
    expect_true(is_plotly(p))
    agg <- distribution(mb, ret = "data", bins = 10L)
    expect_true(extract_target(mb) %in% names(agg))
  })

  it("uses the blueprint's exposure column when set", {
    mb <- mb_glm_poisson_freq()
    agg <- distribution(mb, ret = "data", bins = 10L)
    train <- extract_train(mb)
    expect_equal(sum(agg$exposure), sum(train$exposure))
  })
})
