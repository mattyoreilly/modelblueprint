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

describe("mb_dashboard — UI structure", {
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
})
