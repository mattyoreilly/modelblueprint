# =============================================================================
# test-shap.R
# Tests for shap.R — SHAP importance and dependence plots.
#
# Conventions (matching test-pdp.R):
#   - One describe() block per behaviour group
#   - One it() per behaviour
#   - Tiny nsim / sample_size so tests run fast
#   - All expect_error() calls use fixed = TRUE
#   - skip_if_not_installed("fastshap") guards every test
# =============================================================================

library(testthat)
library(data.table)

skip_on_cran()

# =============================================================================
# Shared fixtures
# =============================================================================

make_df <- function(n = 60L) {
  data.frame(
    x_num = seq(1, 100, length.out = n),
    x_cat = rep(c("A", "B", "C"), length.out = n),
    x_int = rep(1L:5L, length.out = n),
    target = seq(0.2, 1.0, length.out = n),
    expo = rep(1, n),
    stringsAsFactors = FALSE
  )
}

make_lm <- function(df = make_df()) lm(target ~ x_num + x_int, data = df)

is_plotly <- function(x) inherits(x, "plotly")

# Small params to keep tests fast
NSIM <- 5L
NSAMP <- 30L
VARS <- c("x_num", "x_int")


# =============================================================================
# shap.default — ret = "data"
# =============================================================================

describe("shap.default — ret = 'data'", {
  df <- make_df()
  m <- make_lm(df)

  it("returns a data.table", {
    d <- shap(
      df,
      model = m,
      vars = VARS,
      nsim = NSIM,
      sample_size = NSAMP,
      ret = "data"
    )
    expect_s3_class(d, "data.table")
  })

  it("has one column per var", {
    d <- shap(
      df,
      model = m,
      vars = VARS,
      nsim = NSIM,
      sample_size = NSAMP,
      ret = "data"
    )
    expect_identical(sort(names(d)), sort(VARS))
  })

  it("has sample_size rows when data is larger", {
    d <- shap(
      df,
      model = m,
      vars = VARS,
      nsim = NSIM,
      sample_size = NSAMP,
      ret = "data"
    )
    expect_equal(nrow(d), NSAMP)
  })

  it("has nrow(data) rows when data is smaller than sample_size", {
    tiny_df <- make_df(n = 10L)
    tiny_m <- make_lm(tiny_df)
    d <- shap(
      tiny_df,
      model = tiny_m,
      vars = VARS,
      nsim = NSIM,
      sample_size = 500L,
      ret = "data"
    )
    expect_equal(nrow(d), 10L)
  })

  it("returns numeric SHAP columns", {
    d <- shap(
      df,
      model = m,
      vars = VARS,
      nsim = NSIM,
      sample_size = NSAMP,
      ret = "data"
    )
    for (v in names(d)) {
      expect_true(is.numeric(d[[v]]), info = paste("column", v, "not numeric"))
    }
  })
})


# =============================================================================
# shap.default — importance plot
# =============================================================================

describe("shap.default — type = 'importance'", {
  df <- make_df()
  m <- make_lm(df)

  it("returns a plotly object", {
    p <- shap(
      df,
      model = m,
      vars = VARS,
      type = "importance",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_true(is_plotly(p))
  })

  it("works with a single var", {
    p <- shap(
      df,
      model = m,
      vars = "x_num",
      type = "importance",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_true(is_plotly(p))
  })

  it("accepts a custom model_name without error", {
    expect_no_error(
      shap(
        df,
        model = m,
        vars = VARS,
        type = "importance",
        nsim = NSIM,
        sample_size = NSAMP,
        model_name = "my_glm"
      )
    )
  })
})


# =============================================================================
# shap.default — dependence plot
# =============================================================================

describe("shap.default — type = 'dependence'", {
  df <- make_df()
  m <- make_lm(df)

  it("returns a single plotly object for one var", {
    p <- shap(
      df,
      model = m,
      vars = "x_num",
      type = "dependence",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_true(is_plotly(p))
  })

  it("returns a named list of plotly objects for multiple vars", {
    plots <- shap(
      df,
      model = m,
      vars = VARS,
      type = "dependence",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_type(plots, "list")
    expect_identical(sort(names(plots)), sort(VARS))
    for (nm in names(plots)) {
      expect_true(
        is_plotly(plots[[nm]]),
        info = paste("plot for", nm, "not plotly")
      )
    }
  })

  it("handles a categorical feature without error", {
    # x_cat is a character column
    p <- suppressWarnings(
      shap(
        df,
        model = m,
        vars = "x_cat",
        type = "dependence",
        nsim = NSIM,
        sample_size = NSAMP,
        feat_eng_fun = function(d) {
          d$x_cat <- as.integer(factor(d$x_cat))
          d
        }
      )
    )
    expect_true(is_plotly(p))
  })
})


# =============================================================================
# shap.default — input validation
# =============================================================================

describe("shap.default — input validation", {
  df <- make_df()
  m <- make_lm(df)

  it("errors when vars is missing or empty", {
    expect_error(
      shap(
        df,
        model = m,
        vars = character(0L),
        nsim = NSIM,
        sample_size = NSAMP
      ),
      "non-empty character vector",
      fixed = TRUE
    )
  })

  it("errors when a var is not in data", {
    expect_error(
      shap(
        df,
        model = m,
        vars = c("x_num", "does_not_exist"),
        nsim = NSIM,
        sample_size = NSAMP
      ),
      "not found in",
      fixed = TRUE
    )
  })

  it("errors when data is not a data frame or data.table", {
    expect_error(
      shap(
        list(a = 1),
        model = m,
        vars = "a",
        nsim = NSIM,
        sample_size = NSAMP
      ),
      "data frame or data.table",
      fixed = TRUE
    )
  })
})


# =============================================================================
# shap.modelblueprint — basic usage
# =============================================================================

describe("shap.modelblueprint — basic usage", {
  mb <- modelblueprint(
    model = lm(mpg ~ wt + hp + cyl, data = mtcars),
    train = mtcars,
    test = mtcars[1:16, ],
    y_name = "mpg",
    x_original_inputs = c("wt", "hp", "cyl"),
    model_display_name = "lm_mpg"
  )

  it("returns a plotly for importance (default)", {
    p <- shap(mb, nsim = NSIM, sample_size = NSAMP)
    expect_true(is_plotly(p))
  })

  it("returns a plotly for dependence with single var", {
    p <- shap(
      mb,
      vars = "wt",
      type = "dependence",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_true(is_plotly(p))
  })

  it("returns a named list for dependence with multiple vars", {
    plots <- shap(
      mb,
      vars = c("wt", "hp"),
      type = "dependence",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_type(plots, "list")
    expect_named(plots, c("wt", "hp"), ignore.order = TRUE)
  })

  it("returns a data.table for ret = 'data'", {
    d <- shap(mb, nsim = NSIM, sample_size = NSAMP, ret = "data")
    expect_s3_class(d, "data.table")
    expect_true(all(c("wt", "hp", "cyl") %in% names(d)))
  })

  it("uses x_original_inputs when vars = NA", {
    d <- shap(mb, vars = NA, nsim = NSIM, sample_size = NSAMP, ret = "data")
    expect_s3_class(d, "data.table")
    expect_identical(sort(names(d)), sort(c("wt", "hp", "cyl")))
  })

  it("uses test set when set = 'test'", {
    p <- shap(mb, set = "test", nsim = NSIM, sample_size = 16L)
    expect_true(is_plotly(p))
  })
})


# =============================================================================
# shap.modelblueprint — error cases
# =============================================================================

describe("shap.modelblueprint — error cases", {
  it("errors when vars = NA and x_original_inputs is empty", {
    mb_no_inputs <- modelblueprint(
      model = lm(mpg ~ wt, data = mtcars),
      train = mtcars,
      y_name = "mpg"
      # x_original_inputs left as default (empty)
    )
    expect_error(
      shap(mb_no_inputs, vars = NA, nsim = NSIM, sample_size = NSAMP),
      "x_original_inputs",
      fixed = TRUE
    )
  })

  it("errors when set = 'holdout' but holdout is NULL", {
    mb_no_holdout <- modelblueprint(
      model = lm(mpg ~ wt, data = mtcars),
      train = mtcars,
      y_name = "mpg",
      x_original_inputs = "wt"
    )
    expect_error(
      shap(mb_no_holdout, set = "holdout", nsim = NSIM, sample_size = NSAMP),
      "holdout",
      fixed = TRUE
    )
  })
})


# =============================================================================
# shap.default — GLM model
# =============================================================================

describe("shap.default — GLM model", {
  it("works with a binomial GLM", {
    df <- mtcars
    m <- suppressWarnings(glm(vs ~ wt + hp, data = df, family = binomial))
    p <- shap(
      df,
      model = m,
      vars = c("wt", "hp"),
      type = "importance",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_true(is_plotly(p))
  })

  it("works with a Poisson GLM", {
    df <- mtcars
    m <- glm(carb ~ wt + hp + cyl, data = df, family = poisson)
    p <- shap(
      df,
      model = m,
      vars = c("wt", "hp", "cyl"),
      type = "importance",
      nsim = NSIM,
      sample_size = NSAMP
    )
    expect_true(is_plotly(p))
  })
})
