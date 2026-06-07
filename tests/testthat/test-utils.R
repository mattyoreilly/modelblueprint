# =============================================================================
# test-unitise.R
# Tests for unitise()
# =============================================================================

library(testthat)
library(modelblueprint)


# =============================================================================
# Shared fixtures
# =============================================================================

make_df <- function() {
  data.frame(
    x = c(0, 5, 10, 15, 20),
    y = letters[1:5],
    stringsAsFactors = FALSE
  )
}


# =============================================================================
# Input validation
# =============================================================================

describe("unitise — input validation", {
  it("errors when data is not a data.frame or data.table", {
    expect_error(
      unitise(list(x = 1:5), "x", 0, 10),
      "`data` must be a data.frame or data.table.",
      fixed = TRUE
    )
  })

  it("errors when var column does not exist", {
    expect_error(
      unitise(make_df(), "z", 0, 10),
      "column.*z.*not found"
    )
  })

  it("errors when min_val is not numeric", {
    expect_error(
      unitise(make_df(), "x", "zero", 10),
      "`min_val` and `max_val` must be single numeric values.",
      fixed = TRUE
    )
  })

  it("errors when max_val is not numeric", {
    expect_error(
      unitise(make_df(), "x", 0, "ten"),
      "`min_val` and `max_val` must be single numeric values.",
      fixed = TRUE
    )
  })

  it("errors when min_val is a vector", {
    expect_error(
      unitise(make_df(), "x", c(0, 1), 10),
      "`min_val` and `max_val` must be single numeric values.",
      fixed = TRUE
    )
  })

  it("errors when min_val >= max_val", {
    expect_error(
      unitise(make_df(), "x", 10, 0),
      "`min_val` must be less than `max_val`.",
      fixed = TRUE
    )
  })

  it("errors when min_val == max_val", {
    expect_error(
      unitise(make_df(), "x", 5, 5),
      "`min_val` must be less than `max_val`.",
      fixed = TRUE
    )
  })
})


# =============================================================================
# Scaling correctness
# =============================================================================

describe("unitise — scaling correctness", {
  it("min value is scaled to 0", {
    df <- make_df()
    result <- unitise(df, "x", min_val = 0, max_val = 20)
    expect_equal(result$x[df$x == 0], 0)
  })

  it("max value is scaled to 1", {
    df <- make_df()
    result <- unitise(df, "x", min_val = 0, max_val = 20)
    expect_equal(result$x[df$x == 20], 1)
  })

  it("midpoint is scaled to 0.5", {
    df <- make_df()
    result <- unitise(df, "x", min_val = 0, max_val = 20)
    expect_equal(result$x[df$x == 10], 0.5)
  })

  it("all scaled values are in [0, 1]", {
    df <- make_df()
    result <- unitise(df, "x", min_val = 0, max_val = 20)
    expect_true(all(result$x >= 0 & result$x <= 1))
  })

  it("scaling formula is (x - min) / (max - min)", {
    df <- data.frame(x = c(2, 5, 8))
    result <- unitise(df, "x", min_val = 2, max_val = 8)
    expect_equal(result$x, c(0, 0.5, 1), tolerance = 1e-9)
  })

  it("works with negative min_val", {
    df <- data.frame(x = c(-10, 0, 10))
    result <- unitise(df, "x", min_val = -10, max_val = 10)
    expect_equal(result$x, c(0, 0.5, 1), tolerance = 1e-9)
  })

  it("works with non-zero min_val and max_val", {
    df <- data.frame(x = c(3, 5, 7))
    result <- unitise(df, "x", min_val = 3, max_val = 7)
    expect_equal(result$x, c(0, 0.5, 1), tolerance = 1e-9)
  })
})


# =============================================================================
# Capping
# =============================================================================

describe("unitise — capping", {
  it("values below min_val are capped to 0", {
    df <- data.frame(x = c(-100, 5, 10))
    result <- unitise(df, "x", min_val = 0, max_val = 10)
    expect_equal(result$x[1L], 0)
  })

  it("values above max_val are capped to 1", {
    df <- data.frame(x = c(0, 5, 999))
    result <- unitise(df, "x", min_val = 0, max_val = 10)
    expect_equal(result$x[3L], 1)
  })

  it("values within range are not capped", {
    df <- data.frame(x = c(2, 5, 8))
    result <- unitise(df, "x", min_val = 0, max_val = 10)
    expect_equal(result$x, c(0.2, 0.5, 0.8), tolerance = 1e-9)
  })

  it("all values above max_val become 1", {
    df <- data.frame(x = c(100, 200, 300))
    result <- unitise(df, "x", min_val = 0, max_val = 10)
    expect_true(all(result$x == 1))
  })

  it("all values below min_val become 0", {
    df <- data.frame(x = c(-300, -200, -100))
    result <- unitise(df, "x", min_val = 0, max_val = 10)
    expect_true(all(result$x == 0))
  })
})


# =============================================================================
# Return type
# =============================================================================

describe("unitise — return type", {
  it("returns a data.frame when given a data.frame", {
    df <- make_df()
    result <- unitise(df, "x", 0, 20)
    expect_true(is.data.frame(result))
    expect_false(inherits(result, "data.table"))
  })

  it("returns a data.table when given a data.table", {
    dt <- data.table::as.data.table(make_df())
    result <- unitise(dt, "x", 0, 20)
    expect_true(data.table::is.data.table(result))
  })

  it("other columns are unchanged", {
    df <- make_df()
    result <- unitise(df, "x", 0, 20)
    expect_equal(result$y, df$y)
  })

  it("number of rows is unchanged", {
    df <- make_df()
    result <- unitise(df, "x", 0, 20)
    expect_equal(nrow(result), nrow(df))
  })
})


# =============================================================================
# Immutability
# =============================================================================

describe("unitise — immutability", {
  it("does not modify caller's data.frame", {
    df <- make_df()
    x_before <- df$x
    unitise(df, "x", 0, 20)
    expect_equal(df$x, x_before)
  })

  it("does not modify caller's data.table", {
    dt <- data.table::as.data.table(make_df())
    x_before <- dt$x
    unitise(dt, "x", 0, 20)
    expect_equal(dt$x, x_before)
  })
})


# =============================================================================
# Edge cases
# =============================================================================

describe("unitise — edge cases", {
  it("handles NA values — NA in produces NA out", {
    df <- data.frame(x = c(0, NA, 10))
    result <- unitise(df, "x", 0, 10)
    expect_true(is.na(result$x[2L]))
  })

  it("handles a single-row data.frame", {
    df <- data.frame(x = 5)
    result <- unitise(df, "x", 0, 10)
    expect_equal(result$x, 0.5)
  })

  it("coerces integer column to numeric", {
    df <- data.frame(x = as.integer(c(0, 5, 10)))
    result <- unitise(df, "x", 0L, 10L)
    expect_true(is.numeric(result$x))
  })
})
