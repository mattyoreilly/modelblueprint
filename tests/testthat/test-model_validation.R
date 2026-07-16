# =============================================================================
# test-model_validation.R
# Tests for model_validation()
# =============================================================================

library(testthat)
library(modelblueprint)


# =============================================================================
# Fixtures
# =============================================================================

# Every test that builds a blueprint here runs model_validation() end-to-end,
# which always serialises via savemb() (needs arrow) and writes HTML reports
# (needs htmltools). Skip in the fixtures so all tests inherit the guard.
skip_if_missing_mv_deps <- function() {
  skip_if_not_installed("arrow")
  skip_if_not_installed("htmltools")
}

# Minimal lm — 40 rows, 2 features, train + test only (no holdout).
make_mb <- function() {
  skip_if_missing_mv_deps()
  set.seed(1L)
  n  <- 40L
  df <- data.frame(x1 = rnorm(n), x2 = rnorm(n), y = rnorm(n))
  modelblueprint(
    model              = lm(y ~ x1 + x2, data = df[1:30, ]),
    train              = df[1:30, ],
    test               = df[31:40, ],
    y_name             = "y",
    x_original_inputs  = c("x1", "x2"),
    model_display_name = "test_lm"
  )
}

# Same but with a holdout split.
make_mb_with_holdout <- function() {
  skip_if_missing_mv_deps()
  set.seed(2L)
  n  <- 60L
  df <- data.frame(x1 = rnorm(n), y = rnorm(n))
  modelblueprint(
    model              = lm(y ~ x1, data = df[1:42, ]),
    train              = df[1:42, ],
    test               = df[43:51, ],
    holdout            = df[52:60, ],
    y_name             = "y",
    x_original_inputs  = "x1",
    model_display_name = "test_holdout_lm"
  )
}

# Shorthand: run model_validation with safe defaults for tests.
run_mv <- function(mb, ..., plots = "validation", sets = "train") {
  model_validation(
    mb,
    plots         = plots,
    sets          = sets,
    filepath      = withr::local_tempdir(),
    selfcontained = FALSE,
    ...
  )
}

html_path <- function(root, name, set, subdir, suffix) {
  file.path(root, name, subdir, paste0(name, "_", set, "_", suffix, ".html"))
}


# =============================================================================
# Input validation
# =============================================================================

describe("model_validation — input validation", {
  it("errors on non-modelblueprint input", {
    expect_error(run_mv(list(a = 1)))
  })

  it("errors when model_display_name is NA", {
    mb <- set_display_name(make_mb(), NA_character_)
    expect_error(run_mv(mb), "model_display_name")
  })

  it("errors when x_original_inputs is not set", {
    mb <- modelblueprint(
      model              = lm(mpg ~ wt, data = mtcars),
      train              = mtcars,
      y_name             = "mpg",
      model_display_name = "no_features"
    )
    expect_error(run_mv(mb), "x_original_inputs")
  })
})


# =============================================================================
# Directory structure
# =============================================================================

describe("model_validation — directory structure", {
  it("creates root dir named after display_name", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "validation", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(dir.exists(file.path(dir, "test_lm")))
  })

  it("creates validation/ when 'validation' in plots", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "validation", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(dir.exists(file.path(dir, "test_lm", "validation")))
  })

  it("creates oneway/ when 'oneway' in plots", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "oneway", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(dir.exists(file.path(dir, "test_lm", "oneway")))
  })

  it("creates oneway/ when 'stability' in plots (not 'oneway')", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "stability", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(dir.exists(file.path(dir, "test_lm", "oneway")))
  })

  it("creates pdp/ when 'pdp' in plots", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "pdp", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(dir.exists(file.path(dir, "test_lm", "pdp")))
  })

  it("does not create oneway/ when neither oneway nor stability in plots", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "validation", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_false(dir.exists(file.path(dir, "test_lm", "oneway")))
  })

  it("does not create pdp/ when pdp not in plots", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "validation", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_false(dir.exists(file.path(dir, "test_lm", "pdp")))
  })
})


# =============================================================================
# File creation
# =============================================================================

describe("model_validation — file creation", {
  it("creates validation HTML for train and test", {
    skip_if_not_installed("plotly")
    skip_if_not_installed("htmltools")
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "validation",
                     sets = c("train", "test"),
                     filepath = dir, selfcontained = FALSE)
    expect_true(file.exists(
      html_path(dir, "test_lm", "train", "validation", "validation_plots")
    ))
    expect_true(file.exists(
      html_path(dir, "test_lm", "test", "validation", "validation_plots")
    ))
  })

  it("creates oneway HTML for each requested set", {
    skip_if_not_installed("plotly")
    skip_if_not_installed("htmltools")
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "oneway", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(file.exists(
      html_path(dir, "test_lm", "train", "oneway", "oneway_plots")
    ))
  })

  it("creates stability HTML separately from oneway HTML", {
    skip_if_not_installed("plotly")
    skip_if_not_installed("htmltools")
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = c("oneway", "stability"),
                     sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(file.exists(
      html_path(dir, "test_lm", "train", "oneway", "oneway_plots")
    ))
    expect_true(file.exists(
      html_path(dir, "test_lm", "train", "oneway", "stability_plots")
    ))
  })

  it("creates pdp HTML for each requested set", {
    skip_if_not_installed("plotly")
    skip_if_not_installed("htmltools")
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "pdp", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(file.exists(
      html_path(dir, "test_lm", "train", "pdp", "pdp_plots")
    ))
  })

  it("saves modelblueprint .tar.gz to root dir", {
    dir <- withr::local_tempdir()
    model_validation(make_mb(), plots = "validation", sets = "train",
                     filepath = dir, selfcontained = FALSE)
    expect_true(file.exists(file.path(dir, "test_lm", "test_lm.tar.gz")))
  })
})


# =============================================================================
# NULL set skipping
# =============================================================================

describe("model_validation — NULL set skipping", {
  it("warns and skips NULL holdout without erroring", {
    skip_if_not_installed("plotly")
    skip_if_not_installed("htmltools")
    dir <- withr::local_tempdir()
    expect_warning(
      model_validation(make_mb(),
                       sets  = c("train", "holdout"),
                       plots = "validation",
                       filepath = dir, selfcontained = FALSE),
      "holdout"
    )
  })

  it("still creates train file when holdout is skipped", {
    skip_if_not_installed("plotly")
    skip_if_not_installed("htmltools")
    dir <- withr::local_tempdir()
    suppressWarnings(
      model_validation(make_mb(),
                       sets  = c("train", "holdout"),
                       plots = "validation",
                       filepath = dir, selfcontained = FALSE)
    )
    expect_true(file.exists(
      html_path(dir, "test_lm", "train", "validation", "validation_plots")
    ))
    expect_false(file.exists(
      html_path(dir, "test_lm", "holdout", "validation", "validation_plots")
    ))
  })

  it("processes all three sets when holdout is populated", {
    skip_if_not_installed("plotly")
    skip_if_not_installed("htmltools")
    dir <- withr::local_tempdir()
    model_validation(make_mb_with_holdout(),
                     sets  = c("train", "test", "holdout"),
                     plots = "validation",
                     filepath = dir, selfcontained = FALSE)
    for (set in c("train", "test", "holdout")) {
      expect_true(file.exists(
        html_path(dir, "test_holdout_lm", set, "validation", "validation_plots")
      ))
    }
  })
})


# =============================================================================
# Return value
# =============================================================================

describe("model_validation — return value", {
  it("returns root dir path invisibly", {
    dir <- withr::local_tempdir()
    expect_invisible(
      model_validation(make_mb(), plots = "validation", sets = "train",
                       filepath = dir, selfcontained = FALSE)
    )
  })

  it("returned path equals filepath/display_name", {
    dir <- withr::local_tempdir()
    result <- model_validation(make_mb(), plots = "validation", sets = "train",
                               filepath = dir, selfcontained = FALSE)
    expect_equal(result, file.path(dir, "test_lm"))
  })
})
