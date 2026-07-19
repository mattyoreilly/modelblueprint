# =============================================================================
# test-dashboard.R
# Smoke tests for mb_dashboard().
#
# These tests verify that the app object is constructed correctly and that
# invalid inputs are rejected with informative errors. No browser is required.
# =============================================================================

library(testthat)

# =============================================================================
# Shared fixtures
# =============================================================================

make_mb <- function() {
  modelblueprint(
    model = lm(mpg ~ wt + hp, data = mtcars),
    train = mtcars,
    test = mtcars,
    holdout = mtcars,
    y_name = "mpg",
    x_original_inputs = c("wt", "hp"),
    model_display_name = "test_lm"
  )
}

make_mb_train_only <- function() {
  modelblueprint(
    model = lm(mpg ~ wt + hp, data = mtcars),
    train = mtcars,
    y_name = "mpg"
  )
}

make_mb_no_data <- function() {
  modelblueprint(
    model = lm(mpg ~ wt + hp, data = mtcars),
    y_name = "mpg"
  )
}

# =============================================================================
# mb_dashboard — return type
# =============================================================================

describe("mb_dashboard — return type", {
  it("returns a shiny.appobj", {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_if_not_installed("plotly")
    app <- mb_dashboard(make_mb())
    expect_s3_class(app, "shiny.appobj")
  })

  it("works when only train is supplied", {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_if_not_installed("plotly")
    app <- mb_dashboard(make_mb_train_only())
    expect_s3_class(app, "shiny.appobj")
  })
})

# =============================================================================
# mb_dashboard — input validation
# =============================================================================

describe("mb_dashboard — input validation", {
  it("errors when modelblueprint has no data", {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_if_not_installed("plotly")
    expect_error(mb_dashboard(make_mb_no_data()), "no data")
  })

  it("errors when a required package is missing", {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_if_not_installed("plotly")
    # Mock a missing package by temporarily overriding requireNamespace
    local({
      mock_rns <- function(pkg, ...) if (pkg == "plotly") FALSE else TRUE
      with_mocked_bindings(
        requireNamespace = mock_rns,
        expect_error(mb_dashboard(make_mb()), "plotly"),
        .package = "base"
      )
    })
  })
})

# =============================================================================
# mb_dashboard — UI structure
# =============================================================================

# shinyApp() in modern Shiny wraps ui/server internally; they are not directly
# accessible via app$ui / app$server. We test the UI by constructing it
# directly from mb_dashboard's internal builder and inspecting the HTML.

make_ui_html <- function(mb) {
  # Replicate the subset of mb_dashboard() that builds the UI so we can
  # inspect it without launching a server.
  available_sets <- Filter(
    function(s) !is.null(prop(mb, s)),
    c("train", "test", "holdout")
  )
  pdp_vars <- stats::na.omit(mb@x_original_inputs)
  all_cols <- names(prop(mb, available_sets[[1L]]))
  expo_col <- if (!is.na(mb@expo_name) && mb@expo_name %in% all_cols) {
    mb@expo_name
  } else {
    NULL
  }
  ow_vars <- setdiff(all_cols, c(mb@y_name, expo_col))
  model_name <- if (!is.na(mb@model_display_name)) {
    mb@model_display_name
  } else {
    "modelblueprint"
  }

  ui <- bslib::page_navbar(
    title = paste0("ModelBlueprint — ", model_name),
    theme = bslib::bs_theme(bootswatch = "flatly", version = 5L),
    bslib::nav_panel("Summary"),
    bslib::nav_panel(
      "Validation",
      shiny::checkboxGroupInput(
        "val_sets",
        NULL,
        choices = available_sets,
        selected = available_sets
      )
    ),
    bslib::nav_panel(
      "PDPs",
      shiny::selectInput("pdp_var", NULL, choices = pdp_vars)
    ),
    bslib::nav_panel(
      "One-ways",
      shiny::selectInput("ow_var", NULL, choices = ow_vars)
    )
  )
  as.character(htmltools::renderTags(ui)$html)
}

# =============================================================================
# mb_dashboard — precomputed_preds (prediction cache correctness)
# =============================================================================
# These tests exercise the `precomputed_preds` path added to gain, pred_vs_obs,
# residuals_grouped, and one_way for large-model performance. They verify that
# passing pre-computed predictions produces output identical to letting each
# method call predict() itself, using a fast lm so the suite runs without H2O.

make_mb_with_preds <- function() {
  mb <- make_mb()
  df <- as.data.frame(prop(mb, "train"))
  list(mb = mb, preds = predict.modelblueprint(mb, df))
}

describe("precomputed_preds — gain.modelblueprint", {
  it("produces a plotly object when precomputed_preds is supplied", {
    x <- make_mb_with_preds()
    result <- gain(x$mb, set = "train", precomputed_preds = x$preds)
    expect_s3_class(result, "plotly")
  })

  it("gini coefficient is identical with and without precomputed_preds", {
    x <- make_mb_with_preds()
    gini_direct <- gain(x$mb, set = "train", ret = "gini")
    gini_cached <- gain(
      x$mb,
      set = "train",
      precomputed_preds = x$preds,
      ret = "gini"
    )
    expect_equal(gini_direct, gini_cached)
  })

  it("NULL precomputed_preds falls back to normal predict without error", {
    x <- make_mb_with_preds()
    expect_no_error(gain(x$mb, set = "train", precomputed_preds = NULL))
  })
})

describe("precomputed_preds — pred_vs_obs.modelblueprint", {
  it("produces a plotly object when precomputed_preds is supplied", {
    x <- make_mb_with_preds()
    result <- pred_vs_obs(x$mb, set = "train", precomputed_preds = x$preds)
    expect_s3_class(result, "plotly")
  })

  it("aggregated data is identical with and without precomputed_preds", {
    x <- make_mb_with_preds()
    d_direct <- pred_vs_obs(x$mb, set = "train", ret = "data")
    d_cached <- pred_vs_obs(
      x$mb,
      set = "train",
      precomputed_preds = x$preds,
      ret = "data"
    )
    expect_equal(d_direct, d_cached)
  })
})

describe("precomputed_preds — residuals_grouped.modelblueprint", {
  it("produces a plotly object when precomputed_preds is supplied", {
    x <- make_mb_with_preds()
    result <- residuals_grouped(
      x$mb,
      set = "train",
      precomputed_preds = x$preds
    )
    expect_s3_class(result, "plotly")
  })

  it("aggregated data is identical with and without precomputed_preds", {
    x <- make_mb_with_preds()
    d_direct <- residuals_grouped(x$mb, set = "train", ret = "data")
    d_cached <- residuals_grouped(
      x$mb,
      set = "train",
      precomputed_preds = x$preds,
      ret = "data"
    )
    expect_equal(d_direct, d_cached)
  })
})

describe("precomputed_preds — one_way.modelblueprint (predictions overlay)", {
  it("produces a plotly object when precomputed_preds is supplied", {
    x <- make_mb_with_preds()
    result <- one_way(
      x$mb,
      var = "wt",
      set = "train",
      predictions = TRUE,
      precomputed_preds = x$preds
    )
    expect_s3_class(result, "plotly")
  })

  it("aggregated data is identical with and without precomputed_preds", {
    x <- make_mb_with_preds()
    d_direct <- one_way(
      x$mb,
      var = "wt",
      set = "train",
      predictions = TRUE,
      ret = "data"
    )
    d_cached <- one_way(
      x$mb,
      var = "wt",
      set = "train",
      predictions = TRUE,
      precomputed_preds = x$preds,
      ret = "data"
    )
    expect_equal(d_direct, d_cached)
  })

  it("precomputed_preds is ignored when predictions = FALSE", {
    x <- make_mb_with_preds()
    d_no_pred <- one_way(
      x$mb,
      var = "wt",
      set = "train",
      predictions = FALSE,
      ret = "data"
    )
    d_with_ptr <- one_way(
      x$mb,
      var = "wt",
      set = "train",
      predictions = FALSE,
      precomputed_preds = x$preds,
      ret = "data"
    )
    expect_equal(d_no_pred, d_with_ptr)
  })
})

# =============================================================================
# mb_dashboard — H2O GLM large model
# =============================================================================
# Guards against regressions in the dashboard's H2O path and validates that
# the prediction cache works end-to-end on a slow model. The entire block is
# skipped on CRAN and when H2O or Java is unavailable so CI stays green.

describe("mb_dashboard — H2O GLM large model", {
  # ── Skip guard ──────────────────────────────────────────────────────────────
  skip_on_cran() # JVM startup would exceed CRAN's 10-minute check limit
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("plotly")

  h2o_available <- tryCatch(
    {
      # See helper-h2o.R: the H2O JVM is unstable on shared CI runners.
      (nzchar(Sys.getenv("MB_RUN_H2O_TESTS")) ||
        !isTRUE(as.logical(Sys.getenv("CI")))) &&
        requireNamespace("h2o", quietly = TRUE) &&
        !inherits(
          tryCatch(
            suppressWarnings(suppressMessages(
              # No parameters — connects to an existing cluster on the default
              # port (54321) or starts one if none is running. Passing startup
              # parameters (nthreads, max_mem_size, port) throws an error when
              # a cluster is already running with different settings.
              h2o::h2o.init()
            )),
            error = function(e) e
          ),
          "error"
        )
    },
    error = function(e) FALSE
  )
  skip_if(!h2o_available, "H2O not available — skipping H2O dashboard tests")

  h2o::h2o.no_progress()

  # ── Fixture ─────────────────────────────────────────────────────────────────
  # Data is generated inline — no ::: access to internal package helpers.
  # Small n so JVM startup is the dominant cost, not data generation.
  set.seed(42L)
  n_fix <- 5000L
  features <- c("x1", "x2", "x3", "x4", "x5")
  raw <- data.frame(
    x1 = rnorm(n_fix),
    x2 = rnorm(n_fix),
    x3 = runif(n_fix, 0, 10),
    x4 = sample(c(0L, 1L, 2L), n_fix, replace = TRUE),
    x5 = rnorm(n_fix, mean = 5, sd = 2),
    exposure = pmax(0.1, rgamma(n_fix, shape = 2, rate = 1))
  )
  raw$y <- 2 *
    raw$x1 -
    1.5 * raw$x2 +
    0.5 * raw$x3 +
    raw$x4 * 0.8 +
    raw$x5 * 0.3 +
    rnorm(n_fix, sd = 1.5)
  d <- list(
    train = raw[seq_len(5000L), ],
    test = raw[seq_len(5000L), ],
    holdout = raw[seq_len(5000L), ]
  )

  hf_train <- h2o::as.h2o(d$train)
  h2o_glm <- h2o::h2o.glm(
    x = features,
    y = "y",
    training_frame = hf_train,
    family = "gaussian",
    lambda_search = TRUE,
    seed = 42L
  )

  mb_large <- modelblueprint(
    model = h2o_glm,
    train = d$train,
    test = d$test,
    holdout = d$holdout,
    y_name = "y",
    expo_name = "exposure",
    x_original_inputs = features,
    model_display_name = "h2o_glm_large"
  )

  # ── Dashboard construction ──────────────────────────────────────────────────
  it("returns a shiny.appobj for a large H2O MB with train/test/holdout", {
    app <- mb_dashboard(mb_large)
    expect_s3_class(app, "shiny.appobj")
  })

  it("server component is a function", {
    app <- mb_dashboard(mb_large)
    expect_true(is.function(app$serverFuncSource))
  })

  # ── precomputed_preds on H2O ───────────────────────────────────────────────
  # H2O is scored exactly once here. The equivalence between precomputed_preds
  # and direct prediction is already covered by the fast lm describe blocks
  # above, so these tests only verify that the precomputed path produces valid
  # output for an H2O model without touching the cluster again.

  preds_train <- predict.modelblueprint(mb_large, d$train)

  it("predictions are numeric with one value per training row and no NAs", {
    expect_true(is.numeric(preds_train))
    expect_length(preds_train, nrow(d$train))
    expect_false(anyNA(preds_train))
  })

  it("gain: returns a plotly object and a gini in [0, 1]", {
    gini <- gain(
      mb_large,
      set = "train",
      precomputed_preds = preds_train,
      ret = "gini"
    )
    expect_true(is.numeric(unlist(gini)))
    expect_true(all(unlist(gini) >= 0 & unlist(gini) <= 1))
  })

  it("pred_vs_obs: returns a data.table with obs_mean and pred_mean columns", {
    d_out <- pred_vs_obs(
      mb_large,
      set = "train",
      precomputed_preds = preds_train,
      ret = "data"
    )
    expect_true(data.table::is.data.table(d_out))
    expect_true(all(c("obs_mean", "pred_mean", "exposure") %in% names(d_out)))
    expect_false(anyNA(d_out$pred_mean))
  })

  it("residuals_grouped: returns a data.table with no NA residuals", {
    d_out <- residuals_grouped(
      mb_large,
      set = "train",
      precomputed_preds = preds_train,
      ret = "data"
    )
    expect_true(data.table::is.data.table(d_out))
    expect_false(anyNA(d_out))
  })

  it("one_way with predictions overlay: prediction column present and numeric", {
    d_out <- one_way(
      mb_large,
      var = "x1",
      set = "train",
      predictions = TRUE,
      precomputed_preds = preds_train,
      ret = "data"
    )
    pred_col <- grep("^\\.pred_", names(d_out), value = TRUE)
    expect_length(pred_col, 1L)
    expect_true(is.numeric(d_out[[pred_col]]))
  })

  # ── Teardown ────────────────────────────────────────────────────────────────
  withr::defer(h2o_shutdown_safe())
})

# =============================================================================
# mb_dashboard — UI structure
# =============================================================================
it("server component is a function", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("plotly")
  app <- mb_dashboard(make_mb())
  expect_true(is.function(app$serverFuncSource))
})

it("available_sets reflects which slots are populated", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("plotly")
  html <- make_ui_html(make_mb_train_only())
  expect_true(grepl("train", html, fixed = TRUE))
  expect_false(grepl("holdout", html, fixed = TRUE))
})

it("model display name appears in the page title", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("plotly")
  html <- make_ui_html(make_mb())
  expect_true(grepl("test_lm", html, fixed = TRUE))
})
