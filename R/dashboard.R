# =============================================================================
# dashboard.R
# Interactive Shiny dashboard for a modelblueprint object.
# =============================================================================

# Apply a height-independent horizontal legend above the plot area.
# y = 1.02 in paper coordinates is always just above the top of the plot
# regardless of chart height, so this works identically at 320 px and when
# a bslib card is expanded full-screen. The embedded plotly title is cleared
# because bslib card headers already label each chart.
#' @keywords internal
#' @noRd
.val_legend <- function(p) {
  plotly::layout(p,
    title  = "",
    legend = list(
      orientation = "h",
      x           = 0.5, xanchor = "center",
      y           = 1.02, yanchor = "bottom"
    ),
    margin = list(t = 40)
  )
}


#' Launch an interactive dashboard for a modelblueprint
#'
#' Opens a Shiny app that provides an interactive view of a fitted
#' `modelblueprint`. The app has four tabs:
#'
#' - **Summary** -- model class, display name, target, exposure, dataset row
#'   counts, sum of target and exposure per split, the full variable list, and
#'   an overlaid density chart of the target vs model predictions.
#' - **Validation** -- gain chart, predicted vs observed calibration, and
#'   grouped residuals. All three can be shown side-by-side across train, test,
#'   and holdout sets simultaneously, making overfitting immediately visible.
#' - **PDPs** -- partial dependence plot for any variable in
#'   `@x_original_inputs`, with controls for bins, aggregation strategy, and
#'   sample size. Aggregated data can be downloaded as CSV.
#' - **One-ways** -- exposure-weighted mean of the target across bins of any
#'   feature, with an optional model prediction overlay and split variable.
#'   Aggregated data can be downloaded as CSV.
#'
#' All sidebar controls (bins, aggregation type, dataset) update plots
#' reactively. Errors in individual plots are caught and displayed inline so
#' a single failing chart never crashes the app.
#'
#' @param mb A [`modelblueprint`] object. Must have at least one of `@train`,
#'   `@test`, or `@holdout` set.
#' @param ... Currently unused. Reserved for future arguments.
#'
#' @return A `shiny.appobj`. The app launches in the browser when the return
#'   value is printed (the normal behaviour when called interactively). Returns
#'   invisibly when assigned.
#'
#' @section Required packages:
#' `shiny`, `bslib`, and `plotly` must be installed. These are listed under
#' `Suggests` so they are not installed automatically with the package.
#' Install them with:
#' ```r
#' install.packages(c("shiny", "bslib", "plotly"))
#' ```
#' Install `shinycssloaders` for loading spinners on slow plots:
#' ```r
#' install.packages("shinycssloaders")
#' ```
#'
#' @examples
#' \dontrun{
#' mb <- modelblueprint(
#'   model              = glm(vs ~ wt + hp, data = mtcars, family = binomial),
#'   train              = mtcars,
#'   y_name             = "vs",
#'   x_original_inputs  = c("wt", "hp"),
#'   model_display_name = "logistic_vs"
#' )
#'
#' mb_dashboard(mb)
#' }
#'
#' @seealso
#' [pdp()], [one_way()], [pred_vs_obs()], [gain()], [residuals_grouped()]
#' for the underlying functions used inside the dashboard.
#'
#' @export
mb_dashboard <- function(mb, ...) {

  for (pkg in c("shiny", "bslib", "plotly")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(c(
        "Package {.pkg {pkg}} is required for {.fn mb_dashboard}.",
        i = "Install with {.run install.packages('{pkg}')}"
      ))
    }
  }

  has_spinner <- requireNamespace("shinycssloaders", quietly = TRUE)
  spinner <- function(x) {
    if (has_spinner) shinycssloaders::withSpinner(x, type = 6L) else x
  }

  # -- Resolve available sets ------------------------------------------------
  available_sets <- Filter(
    function(s) !is.null(prop(mb, s)),
    c("train", "test", "holdout")
  )
  if (length(available_sets) == 0L) {
    cli::cli_abort("modelblueprint has no data. Supply train/test/holdout when constructing.")
  }

  # -- Variable lists --------------------------------------------------------
  pdp_vars <- stats::na.omit(mb@x_original_inputs)
  if (length(pdp_vars) == 0L) {
    pdp_vars <- setdiff(names(prop(mb, available_sets[[1L]])), mb@y_name)
  }

  all_cols   <- names(prop(mb, available_sets[[1L]]))
  expo_col   <- if (!is.na(mb@expo_name) && mb@expo_name %in% all_cols) mb@expo_name else NULL
  ow_vars    <- setdiff(all_cols, c(mb@y_name, expo_col))
  split_choices <- c("None" = "none", ow_vars)

  model_name <- mb@model_display_name %||% "modelblueprint"

  # ==========================================================================
  # UI
  # ==========================================================================

  # JS helpers injected into the page <head>.
  #
  # 1. shiny:value poller  \u2014 when validation_ui sends new HTML to the browser,
  #    poll Plotly.Plots.resize() every 100 ms for 800 ms.  This catches each
  #    chart as it renders into the updated (possibly narrower/wider) column
  #    layout, regardless of whether it has any sidebar inputs to depend on.
  #
  # 2. bslib full-screen   \u2014 bslib fires 'bslib.card.fullscreen' when a card
  #    enters or exits full-screen mode.  Resize all plots 150 ms later so the
  #    Plotly chart fills the new viewport size.
  resize_script <- shiny::tags$head(shiny::tags$script(shiny::HTML("
    $(document).on('shiny:value', function(ev) {
      if (ev.name !== 'validation_ui') return;
      var polls = 0;
      var timer = setInterval(function() {
        document.querySelectorAll('.js-plotly-plot').forEach(function(el) {
          try { Plotly.Plots.resize(el); } catch(e) {}
        });
        if (++polls >= 8) clearInterval(timer);
      }, 100);
    });

    $(document).on('bslib.card.fullscreen', function() {
      setTimeout(function() {
        document.querySelectorAll('.js-plotly-plot').forEach(function(el) {
          try { Plotly.Plots.resize(el); } catch(e) {}
        });
      }, 150);
    });
  ")))

  ui <- bslib::page_navbar(
    title    = paste0("ModelBlueprint \u2014 ", model_name),
    theme    = bslib::bs_theme(bootswatch = "flatly", version = 5L),
    fillable = FALSE,
    header   = resize_script,

    # -- Summary tab ----------------------------------------------------------
    bslib::nav_panel(
      "Summary",
      icon = shiny::icon("table"),
      bslib::layout_columns(
        col_widths = c(4L, 8L),
        bslib::card(
          bslib::card_header("Model"),
          shiny::tableOutput("model_info")
        ),
        bslib::card(
          bslib::card_header("Datasets"),
          shiny::tableOutput("data_info")
        )
      ),
      bslib::card(
        bslib::card_header("Variables"),
        shiny::tableOutput("var_info")
      ),
      bslib::card(
        bslib::card_header(
          bslib::layout_columns(
            col_widths = c(6L, 3L, 3L),
            "Target vs Predicted Distribution",
            shiny::selectInput(
              "dist_set", label = NULL,
              choices  = available_sets,
              selected = available_sets[[1L]],
              width    = "100%"
            ),
            shiny::numericInput(
              "dist_bins", label = NULL,
              value = 30L, min = 5L, max = 200L, step = 5L,
              width = "100%"
            )
          )
        ),
        spinner(plotly::plotlyOutput("dist_plot", height = "300px"))
      )
    ),

    # -- Validation tab -------------------------------------------------------
    bslib::nav_panel(
      "Validation",
      icon = shiny::icon("chart-line"),
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          shiny::checkboxGroupInput(
            "val_sets", "Sets to show",
            choices  = available_sets,
            selected = available_sets
          ),
          shiny::numericInput(
            "val_bins", "Bins",
            value = 10L, min = 2L, max = 100L, step = 1L
          ),
          shiny::selectInput(
            "val_type_agg", "Aggregation",
            choices  = c("Equal Exposure" = "equal_exposure",
                         "Equal Range"    = "equal_range"),
            selected = "equal_exposure"
          ),
          shiny::numericInput(
            "exposure_per_bin", "Residuals: exposure per bin",
            value = 2500L, min = 10L, step = 100L
          )
        ),
        shiny::uiOutput("validation_ui")
      )
    ),

    # -- PDPs tab -------------------------------------------------------------
    bslib::nav_panel(
      "PDPs",
      icon = shiny::icon("wave-square"),
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          shiny::selectInput(
            "pdp_set", "Dataset",
            choices  = available_sets,
            selected = available_sets[[1L]]
          ),
          shiny::selectInput(
            "pdp_var", "Variable",
            choices = pdp_vars
          ),
          shiny::numericInput(
            "pdp_bins", "Bins",
            value = 10L, min = 2L, max = 100L, step = 1L
          ),
          shiny::selectInput(
            "pdp_type_agg", "Aggregation",
            choices  = c("Equal Exposure" = "equal_exposure",
                         "Equal Range"    = "equal_range"),
            selected = "equal_exposure"
          ),
          shiny::numericInput(
            "pdp_sample_size", "Sample size",
            value = 10000L, min = 100L, max = 100000L, step = 1000L
          ),
          shiny::hr(),
          shiny::downloadButton("pdp_download", "Download data", class = "btn-sm w-100")
        ),
        bslib::card(
          bslib::card_header(shiny::textOutput("pdp_title", inline = TRUE)),
          spinner(plotly::plotlyOutput("pdp_plot", height = "500px"))
        )
      )
    ),

    # -- One-ways tab ---------------------------------------------------------
    bslib::nav_panel(
      "One-ways",
      icon = shiny::icon("chart-bar"),
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          shiny::selectInput(
            "ow_set", "Dataset",
            choices  = available_sets,
            selected = available_sets[[1L]]
          ),
          shiny::selectInput(
            "ow_var", "Variable",
            choices = ow_vars
          ),
          shiny::numericInput(
            "ow_bins", "Bins",
            value = 35L, min = 2L, max = 100L, step = 1L
          ),
          shiny::selectInput(
            "ow_type_agg", "Aggregation",
            choices  = c("Equal Exposure" = "equal_exposure",
                         "Equal Range"    = "equal_range"),
            selected = "equal_exposure"
          ),
          shiny::selectInput(
            "ow_split", "Split by",
            choices  = split_choices,
            selected = "none"
          ),
          shiny::checkboxInput("ow_predictions", "Overlay predictions", value = FALSE),
          shiny::hr(),
          shiny::downloadButton("ow_download", "Download data", class = "btn-sm w-100")
        ),
        bslib::card(
          bslib::card_header(shiny::textOutput("ow_title", inline = TRUE)),
          spinner(plotly::plotlyOutput("ow_plot", height = "500px"))
        )
      )
    )
  )

  # ==========================================================================
  # Server
  # ==========================================================================

  server <- function(input, output, session) {

    # -- Prediction cache -------------------------------------------------------
    # Predictions are computed once per set on first access and reused across
    # all plots (gain, pred_vs_obs, residuals_grouped, dist_plot, one_way).
    # This avoids 4+ independent full-dataset predict() calls for large models.
    # .pred_env stores two keys per set:
    #   <set>           \u2014 numeric prediction vector, or NULL if not yet computed
    #   <set>_attempted \u2014 TRUE once a prediction attempt has been made
    #
    # The "attempted" flag prevents retrying a failed prediction on every
    # subsequent plot render, which would flood the UI with repeated curl /
    # connection errors.
    .pred_env <- new.env(parent = emptyenv())
    get_preds <- function(set) {
      attempted <- isTRUE(.pred_env[[paste0(set, "_attempted")]])
      if (!attempted) {
        .pred_env[[paste0(set, "_attempted")]] <- TRUE
        nid <- shiny::showNotification(
          paste0("Computing predictions for ", set, " set\u2026"),
          duration = NULL, type = "message", id = paste0("pred_", set)
        )
        on.exit(shiny::removeNotification(nid), add = TRUE)
        df <- as.data.frame(prop(mb, set))
        .pred_env[[set]] <- tryCatch(
          predict.modelblueprint(mb, df),
          error = function(e) {
            msg <- conditionMessage(e)
            # Give H2O connection failures an actionable hint
            if (grepl("curl|localhost|connect", msg, ignore.case = TRUE)) {
              msg <- paste0(
                "Could not reach the H2O cluster. ",
                "Call h2o::h2o.init() before launching mb_dashboard(). ",
                "(", msg, ")"
              )
            }
            shiny::showNotification(
              paste0("[", set, "] Prediction failed: ", msg),
              type = "error", duration = NULL,
              id   = paste0("pred_err_", set)
            )
            NULL
          }
        )
      }
      .pred_env[[set]]
    }

    # -- Debounced PDP inputs ---------------------------------------------------
    # Prevents predict() from firing on every slider tick for slow models.
    pdp_inputs <- shiny::reactive(list(
      var      = input$pdp_var,
      set      = input$pdp_set,
      bins     = input$pdp_bins,
      type_agg = input$pdp_type_agg,
      sample   = input$pdp_sample_size
    ))
    pdp_inputs_d <- shiny::debounce(pdp_inputs, millis = 800L)

    # -- Summary: tables -------------------------------------------------------

    output$model_info <- shiny::renderTable({
      data.frame(
        Field = c("Class", "Display name", "Target", "Exposure", "Deploy notes"),
        Value = c(
          paste(class(mb@model), collapse = "/"),
          if (is.na(mb@model_display_name)) "\u2014" else mb@model_display_name,
          if (is.na(mb@y_name))             "\u2014" else mb@y_name,
          if (is.na(mb@expo_name))          "\u2014" else mb@expo_name,
          if (is.na(mb@deploy_notes))       "\u2014" else mb@deploy_notes
        ),
        stringsAsFactors = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%")

    output$data_info <- shiny::renderTable({
      sets     <- c("train", "test", "holdout")
      y_col    <- mb@y_name
      e_col    <- if (!is.na(mb@expo_name)) mb@expo_name else NULL
      fmt      <- function(x) format(round(x), big.mark = ",")

      data.frame(
        Set = sets,
        Rows = vapply(sets, function(s) {
          d <- prop(mb, s)
          if (is.null(d)) "\u2014" else format(nrow(d), big.mark = ",")
        }, character(1L)),
        `Sum target` = vapply(sets, function(s) {
          d <- prop(mb, s)
          if (is.null(d) || is.na(y_col) || !y_col %in% names(d)) "\u2014"
          else fmt(sum(d[[y_col]], na.rm = TRUE))
        }, character(1L)),
        `Sum exposure` = vapply(sets, function(s) {
          d <- prop(mb, s)
          if (is.null(d) || is.null(e_col) || !e_col %in% names(d)) "\u2014"
          else fmt(sum(d[[e_col]], na.rm = TRUE))
        }, character(1L)),
        stringsAsFactors = FALSE,
        check.names      = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%")

    output$var_info <- shiny::renderTable({
      orig <- stats::na.omit(mb@x_original_inputs)
      eng  <- stats::na.omit(mb@x_names)
      data.frame(
        Type     = c(rep("Original input", length(orig)),
                     rep("Engineered",     length(eng))),
        Variable = c(orig, eng),
        stringsAsFactors = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%")

    # -- Summary: distribution plot -------------------------------------------

    output$dist_plot <- plotly::renderPlotly({
      shiny::req(input$dist_set, input$dist_bins, !is.na(mb@y_name))
      df   <- as.data.frame(prop(mb, input$dist_set))
      pred <- get_preds(input$dist_set)
      bins <- input$dist_bins

      # Divide observed target by exposure to show the rate.
      # Fall back to raw target if exposure is absent or all-zero.
      expo_col <- resolve_exposure(mb, df)
      expo     <- if (expo_col == "vec_of_ones") rep(1, nrow(df)) else df[[expo_col]]
      obs      <- df[[mb@y_name]] / expo
      x_title  <- if (expo_col == "vec_of_ones") mb@y_name
                  else paste0(mb@y_name, " / ", expo_col)

      p <- plotly::plot_ly(
          x = obs, type = "histogram", histnorm = "probability density",
          nbinsx = bins, name = "Observed", opacity = 0.65,
          marker = list(color = "#F8766D", line = list(color = "#F8766D", width = 0.5))
        ) |>
        plotly::layout(
          barmode = "overlay",
          xaxis   = list(title = x_title),
          yaxis   = list(title = "Density"),
          legend  = list(x = 1.05, y = 0.5),
          plot_bgcolor  = "rgba(0,0,0,0)",
          paper_bgcolor = "rgba(0,0,0,0)"
        )

      if (!is.null(pred)) {
        p <- plotly::add_histogram(
          p, x = pred, histnorm = "probability density",
          nbinsx = bins, name = "Predicted", opacity = 0.65,
          marker = list(color = "#619CFF", line = list(color = "#619CFF", width = 0.5))
        )
      }
      p
    })

    # -- Validation -----------------------------------------------------------

    output$validation_ui <- shiny::renderUI({
      sets <- shiny::req(input$val_sets)

      chart_card <- function(title, out_id) {
        bslib::card(
          full_screen = TRUE,
          bslib::card_header(title),
          plotly::plotlyOutput(out_id, height = "320px")
        )
      }

      cols <- lapply(sets, function(s) {
        bslib::card(
          bslib::card_header(toupper(s)),
          chart_card("Gain",                  paste0("gain_",  s)),
          chart_card("Predicted vs Observed", paste0("pvo_",   s)),
          chart_card("Residuals",             paste0("resid_", s))
        )
      })

      n      <- length(cols)
      widths <- switch(as.character(n), "1" = 12L, "2" = 6L, "3" = 4L, rep(4L, n))
      do.call(bslib::layout_columns, c(list(col_widths = widths), cols))
    })

    lapply(available_sets, function(set) {

      output[[paste0("gain_", set)]] <- plotly::renderPlotly({
        input$val_sets  # re-render whenever column layout changes
        tryCatch(
          .val_legend(gain(mb, set = set, precomputed_preds = get_preds(set))),
          error = function(e) plotly::plotly_empty() |> plotly::layout(title = conditionMessage(e)))
      })

      output[[paste0("pvo_", set)]] <- plotly::renderPlotly({
        input$val_sets
        tryCatch(
          .val_legend(pred_vs_obs(mb, set = set, bins = input$val_bins,
                                  type_agg = input$val_type_agg,
                                  precomputed_preds = get_preds(set))),
          error = function(e) plotly::plotly_empty() |> plotly::layout(title = conditionMessage(e)))
      })

      output[[paste0("resid_", set)]] <- plotly::renderPlotly({
        input$val_sets
        tryCatch(
          .val_legend(residuals_grouped(mb, set = set,
                                        exposure_per_bin = input$exposure_per_bin,
                                        precomputed_preds = get_preds(set))),
          error = function(e) plotly::plotly_empty() |> plotly::layout(title = conditionMessage(e)))
      })
    })

    # -- PDPs -----------------------------------------------------------------

    output$pdp_title <- shiny::renderText({
      p <- pdp_inputs_d()
      paste("PDP \u2014", p$var, "\u2014", p$set)
    })

    pdp_data <- shiny::reactive({
      p <- pdp_inputs_d()
      shiny::req(p$var)
      tryCatch(
        pdp(mb, var = p$var, set = p$set, bins = p$bins,
            type_agg = p$type_agg, sample_size = p$sample, ret = "data"),
        error = function(e) NULL
      )
    })

    output$pdp_plot <- plotly::renderPlotly({
      p <- pdp_inputs_d()
      shiny::req(p$var)
      tryCatch(
        pdp(mb, var = p$var, set = p$set, bins = p$bins,
            type_agg = p$type_agg, sample_size = p$sample),
        error = function(e) plotly::plotly_empty() |> plotly::layout(title = conditionMessage(e))
      )
    })

    output$pdp_download <- shiny::downloadHandler(
      filename = function() {
        p <- shiny::isolate(pdp_inputs_d())
        paste0("pdp_", p$var, "_", p$set, ".csv")
      },
      content  = function(file) {
        d <- pdp_data()
        if (!is.null(d)) utils::write.csv(d, file, row.names = FALSE)
      }
    )

    # -- One-ways -------------------------------------------------------------

    output$ow_title <- shiny::renderText(paste("One-way \u2014", input$ow_var, "\u2014", input$ow_set))

    ow_split <- shiny::reactive({
      if (is.null(input$ow_split) || input$ow_split == "none") NA_character_ else input$ow_split
    })

    ow_data <- shiny::reactive({
      shiny::req(input$ow_var)
      preds <- if (isTRUE(input$ow_predictions)) get_preds(input$ow_set) else NULL
      tryCatch(
        one_way(mb, var = input$ow_var, set = input$ow_set, bins = input$ow_bins,
                type_agg = input$ow_type_agg, predictions = input$ow_predictions,
                split = ow_split(), ret = "data", precomputed_preds = preds),
        error = function(e) NULL
      )
    })

    output$ow_plot <- plotly::renderPlotly({
      shiny::req(input$ow_var)
      preds <- if (isTRUE(input$ow_predictions)) get_preds(input$ow_set) else NULL
      tryCatch(
        one_way(mb, var = input$ow_var, set = input$ow_set, bins = input$ow_bins,
                type_agg = input$ow_type_agg, predictions = input$ow_predictions,
                split = ow_split(), precomputed_preds = preds),
        error = function(e) plotly::plotly_empty() |> plotly::layout(title = conditionMessage(e))
      )
    })

    output$ow_download <- shiny::downloadHandler(
      filename = function() paste0("oneway_", input$ow_var, "_", input$ow_set, ".csv"),
      content  = function(file) {
        d <- ow_data()
        if (!is.null(d)) utils::write.csv(d, file, row.names = FALSE)
      }
    )
  }

  shiny::shinyApp(ui, server)
}
