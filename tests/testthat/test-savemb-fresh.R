# =============================================================================
# test-savemb-fresh.R
# savemb()/loadmb() round-trips across R sessions.
#
# Same-session round-trip tests cannot prove an archive is self-contained:
# models with external state (xgboost C++ handles, H2O objects living in the
# JVM) may predict through pointers that are still alive in the saving
# session. Here the model is fitted, scored, and saved in one throwaway R
# session; that session then dies (and for H2O its JVM is explicitly shut
# down) before a second fresh session loads the archive and scores again.
# Nothing is shared between the two sessions except the .tar.gz on disk.
# =============================================================================

# Run `fun(args)` in a fresh R session with modelblueprint available.
# Under R CMD check the package is installed in the session library, so the
# child just library()s it. Under devtools::test() it is only load_all()-ed,
# so the child load_all()s the source tree instead.
run_fresh <- function(fun, args = list()) {
  dev <- requireNamespace("pkgload", quietly = TRUE) &&
    pkgload::is_dev_package("modelblueprint")
  pkg_root <- if (dev) normalizePath(test_path("..", "..")) else NA_character_
  callr::r(
    function(fun, args, pkg_root) {
      if (is.na(pkg_root)) {
        library(modelblueprint)
      } else {
        pkgload::load_all(pkg_root, quiet = TRUE)
      }
      do.call(fun, args)
    },
    args = list(fun = fun, args = args, pkg_root = pkg_root),
    libpath = .libPaths()
  )
}

skip_if_missing_fresh_deps <- function() {
  skip_on_cran()
  skip_if_not_installed("callr")
  skip_if_not_installed("arrow")
}


describe("savemb / loadmb — fresh-session round-trips", {
  it("lm archive predicts identically in a fresh session", {
    skip_if_missing_fresh_deps()
    tmp <- withr::local_tempdir()

    preds_before <- run_fresh(function(dir) {
      mb <- mb_lm_regression()
      savemb(mb, path = dir, filename = "fresh_lm")
      predict(mb, mb@train)
    }, list(dir = tmp))

    preds_after <- run_fresh(function(dir) {
      loaded <- loadmb(file.path(dir, "fresh_lm.tar.gz"))
      predict(loaded, loaded@train)
    }, list(dir = tmp))

    expect_equal(preds_after, preds_before, tolerance = 1e-8)
  })

  it("xgboost archive predicts identically in a fresh session", {
    skip_if_missing_fresh_deps()
    skip_if_not_installed("xgboost")
    tmp <- withr::local_tempdir()

    preds_before <- run_fresh(function(dir) {
      mb <- mb_xgb_regression()
      savemb(mb, path = dir, filename = "fresh_xgb")
      predict(mb, mb@train)
    }, list(dir = tmp))

    preds_after <- run_fresh(function(dir) {
      loaded <- loadmb(file.path(dir, "fresh_xgb.tar.gz"))
      predict(loaded, loaded@train)
    }, list(dir = tmp))

    expect_equal(preds_after, preds_before, tolerance = 1e-6)
  })

  it("h2o archive predicts identically after the JVM is shut down", {
    skip_if_missing_fresh_deps()
    # h2o_init_safe() carries the CI gating (skip_on_ci unless
    # MB_RUN_H2O_TESTS) and skips cleanly when Java/h2o can't start, so a
    # broken local Java shows as a skip here rather than a child-process error.
    h2o_init_safe()
    tmp <- withr::local_tempdir()

    # Each child gets its own port AND cluster name: the loading session can
    # then never attach to the saving session's cluster (attaching would let
    # predictions come from model keys still alive in the old JVM, defeating
    # the test), and shutdown timing races on a shared port cannot flake it.
    preds_before <- run_fresh(function(dir) {
      suppressWarnings(suppressMessages(
        h2o::h2o.init(nthreads = 1L, port = 54350L, name = "mb_fresh_save")
      ))
      h2o::h2o.no_progress()

      df <- mtcars
      hf <- h2o::as.h2o(df)
      model <- h2o::h2o.glm(x = c("wt", "hp"), y = "mpg", training_frame = hf)
      mb <- modelblueprint(
        model              = model,
        train              = df,
        y_name             = "mpg",
        x_original_inputs  = c("wt", "hp"),
        model_display_name = "fresh_h2o"
      )
      preds <- predict(mb, df)
      savemb(mb, path = dir, filename = "fresh_h2o")
      tryCatch(
        suppressMessages(h2o::h2o.shutdown(prompt = FALSE)),
        error = function(e) NULL
      )
      preds
    }, list(dir = tmp))

    preds_after <- run_fresh(function(dir) {
      # Brand-new JVM on its own port; the saving JVM is dead or dying and
      # unreachable from here either way.
      suppressWarnings(suppressMessages(
        h2o::h2o.init(nthreads = 1L, port = 54360L, name = "mb_fresh_load")
      ))
      h2o::h2o.no_progress()
      loaded <- loadmb(file.path(dir, "fresh_h2o.tar.gz"))
      preds <- predict(loaded, loaded@train)
      tryCatch(
        suppressMessages(h2o::h2o.shutdown(prompt = FALSE)),
        error = function(e) NULL
      )
      preds
    }, list(dir = tmp))

    expect_equal(preds_after, preds_before, tolerance = 1e-6)
  })
})
