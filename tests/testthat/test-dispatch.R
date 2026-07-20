# =============================================================================
# test-dispatch.R
# Guards method dispatch on the S7 classes (modelblueprint / mb_seq / mb_layer).
#
# An S7 object's implicit class is the package-qualified string
# "modelblueprint::modelblueprint", so every S3 generic and every S7 method()
# must be registered under that name (see .onLoad() in modelblueprint.R). This
# file calls each verb on a real S7 object so that a future S7 release, or an
# accidental edit to the registration block, can't silently break dispatch.
#
# Because testthat runs this file under pkgload::load_all() during
# devtools::test() AND under library(modelblueprint) during R CMD check, the
# single file exercises both load paths.
# =============================================================================

make_dispatch_mb <- function() {
  modelblueprint(
    model              = stats::lm(mpg ~ wt + hp + cyl, data = mtcars),
    train              = mtcars,
    test               = mtcars[1:16, ],
    y_name             = "mpg",
    x_original_inputs  = c("wt", "hp", "cyl"),
    model_display_name = "dispatch_lm"
  )
}


test_that("the object really is an S7 object with the qualified class", {
  mb <- make_dispatch_mb()
  expect_true(S7::S7_inherits(mb, modelblueprint))
  # The first element of the implicit class is what UseMethod() dispatches on.
  expect_identical(class(mb)[[1L]], "modelblueprint::modelblueprint")
})


test_that("base S3 generics (print / predict) dispatch to S7 methods", {
  mb <- make_dispatch_mb()

  # print() must hit .print_modelblueprint(), not the default S7 printer.
  expect_output(print(mb), "modelblueprint")
  expect_invisible(print(mb))

  preds <- predict(mb, mtcars)
  expect_type(preds, "double")
  expect_length(preds, nrow(mtcars))
})


test_that("dplyr S3 generics (filter / mutate / left_join) dispatch", {
  mb <- make_dispatch_mb()

  mb_f <- dplyr::filter(mb, cyl == 4)
  expect_true(S7::S7_inherits(mb_f, modelblueprint))
  expect_lt(nrow(extract_train(mb_f)), nrow(mtcars))

  mb_m <- dplyr::mutate(mb, wt2 = wt * 2)
  expect_true("wt2" %in% names(extract_train(mb_m)))

  key <- data.frame(cyl = c(4, 6, 8), grp = c("a", "b", "c"))
  mb_j <- dplyr::left_join(mb, key, by = "cyl")
  expect_true("grp" %in% names(extract_train(mb_j)))
})


test_that("every extract_* accessor dispatches", {
  mb <- make_dispatch_mb()

  expect_s3_class(extract_fit(mb), "lm")
  expect_s3_class(extract_train(mb), "data.frame")
  expect_s3_class(extract_test(mb), "data.frame")
  expect_null(extract_holdout(mb))
  expect_type(extract_pre_process_fun(mb), "closure")
  expect_type(extract_feat_eng_fun(mb), "closure")
  expect_type(extract_post_process_fun(mb), "closure")
  expect_identical(as.character(extract_original_inputs(mb)),
                   c("wt", "hp", "cyl"))
  expect_identical(extract_target(mb), "mpg")
  expect_identical(extract_display_name(mb), "dispatch_lm")
  # Scalar metadata accessors return without error
  expect_no_error(extract_yhat_name(mb))
  expect_no_error(extract_exposure_name(mb))
  expect_no_error(extract_exposure_value(mb))
  expect_no_error(extract_exposure_zero_rep(mb))
  expect_no_error(extract_offset_name(mb))
  expect_no_error(extract_offset_value(mb))
  expect_no_error(extract_deploy_notes(mb))
})


test_that("every set_* verb dispatches and returns a modelblueprint", {
  mb <- make_dispatch_mb()

  setters <- list(
    set_model             = stats::lm(mpg ~ wt, data = mtcars),
    set_train             = mtcars,
    set_test              = mtcars,
    set_holdout           = mtcars,
    set_pre_process_fun   = function(df) df,
    set_feat_eng_fun      = function(df) df,
    set_post_process_fun  = function(preds, df_raw) preds,
    set_original_inputs   = c("wt", "hp"),
    set_feature_names     = c("wt", "hp"),
    set_target            = "mpg",
    set_yhat_name         = "yhat",
    set_exposure_name     = "exposure",
    set_exposure_value    = 1,
    set_exposure_zero_rep = 0.1,
    set_offset_name       = "wt",
    set_offset_value      = 0,
    set_display_name      = "renamed",
    set_deploy_notes      = "notes"
  )

  for (nm in names(setters)) {
    fn  <- get(nm, envir = asNamespace("modelblueprint"))
    out <- fn(mb, setters[[nm]])
    expect_true(S7::S7_inherits(out, modelblueprint),
                info = paste(nm, "did not return a modelblueprint"))
  }

  # Sanity: a setter actually changed the slot.
  expect_identical(extract_display_name(set_display_name(mb, "renamed")),
                   "renamed")
})


test_that("diagnostic S3 generics dispatch on the modelblueprint method", {
  mb <- make_dispatch_mb()

  expect_s3_class(suppressMessages(one_way(mb, var = "wt")), "plotly")
  expect_s3_class(suppressMessages(distribution(mb)), "plotly")
  expect_s3_class(suppressMessages(pdp(mb, var = "wt")), "plotly")
  expect_s3_class(suppressMessages(gain(mb, set = "train")), "plotly")
  expect_s3_class(suppressMessages(pred_vs_obs(mb, set = "train")), "plotly")
  expect_s3_class(suppressMessages(residuals_grouped(mb, set = "train")), "plotly")
  expect_s3_class(
    suppressMessages(
      shap(mb, vars = c("wt", "hp"), nsim = 3L, sample_size = 20L)
    ),
    "plotly"
  )
})


test_that("savemb is an S7 generic that dispatches and round-trips", {
  skip_if_not_installed("arrow")
  mb  <- make_dispatch_mb()
  dir <- withr::local_tempdir()

  path <- suppressMessages(
    savemb(mb, path = dir, filename = "dispatch_lm")
  )
  expect_true(file.exists(path))

  mb2 <- suppressMessages(loadmb(path))
  expect_true(S7::S7_inherits(mb2, modelblueprint))
  expect_equal(
    unname(predict(mb2, mtcars)),
    unname(predict(mb, mtcars))
  )
})


test_that("mb_seq / mb_layer print and predict dispatch", {
  # Clear @expo_name (default "exposure") since mtcars has no such column and
  # mb_seq() validates that every declared exposure column is present.
  mb <- make_dispatch_mb()
  mb <- set_exposure_name(mb, NA_character_)
  mb <- set_yhat_name(mb, "pred_mpg")
  seq1 <- mb_seq(mb_layer(list(mb)), train = mtcars, y_name = "mpg")

  # mb_seq / mb_layer print via cli (message stream, not stdout), so assert the
  # methods dispatch and run rather than capturing text. Each returns its input
  # invisibly, confirming it hit the registered method, not the default printer.
  expect_no_error(print(seq1))
  expect_invisible(print(seq1))
  expect_no_error(print(mb_layer(list(mb))))

  out <- predict(seq1, mtcars)
  expect_type(out, "double")
  expect_length(out, nrow(mtcars))
})
