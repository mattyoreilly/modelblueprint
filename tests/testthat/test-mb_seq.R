# test-mb_seq.R

library(testthat)
library(data.table)

# =============================================================================
# Fixtures
# =============================================================================

make_df <- function(n = 100L) {
  data.frame(
    x1       = seq(1, 10, length.out = n),
    x2       = seq(0.1, 1, length.out = n),
    target   = seq(0.5, 5, length.out = n),
    exposure = rep(1, n),
    stringsAsFactors = FALSE
  )
}

make_mb <- function(yhat_name, formula = target ~ x1) {
  df <- make_df()
  modelblueprint(
    model = lm(formula, data = df),
    train = df,
    y_name = "target",
    yhat_name = yhat_name
  )
}

# =============================================================================
# mb_layer — S7 class identity
# =============================================================================

describe("mb_layer — S7 class", {
  it("is an S7 object with the qualified class name", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_true(inherits(layer, "modelblueprint::mb_layer"))
  })

  it("is no longer a plain S3 list", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_false(is.list(layer) && identical(class(layer), "mb_layer"))
  })

  it("exposes @blueprints as a list", {
    mb <- make_mb("pred_a")
    layer <- mb_layer(list(mb))
    expect_true(is.list(layer@blueprints))
    expect_length(layer@blueprints, 1L)
  })

  it("exposes @aggregate_fn as a function", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_true(is.function(layer@aggregate_fn))
  })

  it("exposes @yhat_name as a character string", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_equal(layer@yhat_name, "pred_a")
  })
})


# =============================================================================
# mb_layer — construction
# =============================================================================

describe("mb_layer — construction", {
  it("constructs with a single blueprint and no aggregate_fn", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_true(inherits(layer, "modelblueprint::mb_layer"))
  })

  it("yhat_name defaults to the single blueprint's yhat_name", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_equal(layer@yhat_name, "pred_a")
  })

  it("explicit yhat_name overrides the blueprint default", {
    layer <- mb_layer(list(make_mb("pred_a")), yhat_name = "pred_a")
    expect_equal(layer@yhat_name, "pred_a")
  })

  it("aggregate_fn defaults to identity for a single blueprint", {
    mb <- make_mb("pred_a")
    layer <- mb_layer(list(mb))
    df <- make_df()
    df[["pred_a"]] <- 1:nrow(df)
    expect_equal(layer@aggregate_fn(df), df)
  })

  it("constructs with multiple blueprints and explicit aggregate_fn", {
    layer <- mb_layer(
      blueprints   = list(make_mb("pred_a"), make_mb("pred_b", target ~ x2)),
      yhat_name    = "pred_combined",
      aggregate_fn = function(df) {
        df[["pred_combined"]] <- df[["pred_a"]] + df[["pred_b"]]
        df
      }
    )
    expect_true(inherits(layer, "modelblueprint::mb_layer"))
    expect_equal(layer@yhat_name, "pred_combined")
  })

  it("errors when blueprints is empty", {
    expect_error(mb_layer(list()), "non-empty")
  })

  it("errors when blueprints is not a list", {
    expect_error(mb_layer("not_a_list"), "non-empty")
  })

  it("errors when a blueprint is not a modelblueprint object", {
    expect_error(mb_layer(list("not_an_mb")), "modelblueprint")
  })

  it("errors when a blueprint has no yhat_name set", {
    mb_no_yhat <- modelblueprint(
      model  = lm(target ~ x1, data = make_df()),
      y_name = "target"
    )
    expect_error(mb_layer(list(mb_no_yhat)), "yhat_name")
  })

  it("errors when aggregate_fn is not a function", {
    expect_error(
      mb_layer(list(make_mb("pred_a")), aggregate_fn = "not_a_function"),
      "function"
    )
  })

  it("errors when multiple blueprints and no aggregate_fn", {
    expect_error(
      mb_layer(list(make_mb("pred_a"), make_mb("pred_b")), yhat_name = "c"),
      "aggregate_fn"
    )
  })

  it("errors when multiple blueprints and no yhat_name", {
    expect_error(
      mb_layer(
        list(make_mb("pred_a"), make_mb("pred_b")),
        aggregate_fn = function(df) df
      ),
      "yhat_name"
    )
  })

  it("reports both missing aggregate_fn and yhat_name in one error", {
    err <- tryCatch(
      mb_layer(list(make_mb("pred_a"), make_mb("pred_b"))),
      error = function(e) conditionMessage(e)
    )
    expect_match(err, "aggregate_fn")
    expect_match(err, "yhat_name")
  })
})


# =============================================================================
# mb_seq — construction
# =============================================================================

describe("mb_seq — construction", {
  it("constructs with a single layer", {
    seq1 <- mb_seq(mb_layer(list(make_mb("pred_a"))))
    expect_true(inherits(seq1, "modelblueprint::mb_seq"))
  })

  it("constructs with multiple layers", {
    seq2 <- mb_seq(
      mb_layer(list(make_mb("pred_a"))),
      mb_layer(list(make_mb("pred_b"))),
      model_display_name = "test_seq"
    )
    expect_true(inherits(seq2, "modelblueprint::mb_seq"))
    expect_equal(seq2@model_display_name, "test_seq")
  })

  it("stores train/test/holdout slots", {
    df <- make_df()
    seq1 <- mb_seq(
      mb_layer(list(make_mb("pred_a"))),
      train   = df,
      test    = df,
      holdout = df
    )
    expect_equal(nrow(seq1@train), nrow(df))
    expect_equal(nrow(seq1@test), nrow(df))
    expect_equal(nrow(seq1@holdout), nrow(df))
  })

  it("errors when no layers are supplied", {
    expect_error(mb_seq(), "mb_layer")
  })

  it("errors when a positional argument is not an mb_layer", {
    expect_error(mb_seq("not_a_layer"), "mb_layer")
  })

  it("errors when y_name is not in the supplied data", {
    df <- make_df()
    expect_error(
      mb_seq(mb_layer(list(make_mb("pred_a"))), train = df, y_name = "missing_col"),
      "missing_col"
    )
  })

  it("errors when expo_name is not in the supplied data", {
    df <- make_df()
    expect_error(
      mb_seq(mb_layer(list(make_mb("pred_a"))), train = df, expo_name = "missing_expo"),
      "missing_expo"
    )
  })

  it("errors when a blueprint's x_original_inputs are missing from the data", {
    # Now caught at modelblueprint() construction time — fail early.
    df <- make_df()
    expect_error(
      modelblueprint(
        model             = lm(target ~ x1, data = df),
        train             = df,
        y_name            = "target",
        yhat_name         = "pred_a",
        x_original_inputs = c("x1", "x_missing")
      ),
      "x_missing"
    )
  })
})


# =============================================================================
# predict.mb_seq — return_all = FALSE (default)
# =============================================================================

describe("predict.mb_seq — returns a numeric vector by default", {
  df   <- make_df()
  seq1 <- mb_seq(mb_layer(list(make_mb("pred_a"))))

  it("returns a numeric vector", {
    expect_true(is.numeric(predict(seq1, df)))
  })

  it("returns one value per row", {
    expect_equal(length(predict(seq1, df)), nrow(df))
  })

  it("predictions are finite", {
    expect_true(all(is.finite(predict(seq1, df))))
  })

  it("errors when newdata is missing", {
    expect_error(predict(seq1), "newdata")
  })

  it("accepts a data.table as newdata", {
    dt <- data.table::as.data.table(df)
    preds <- predict(seq1, dt)
    expect_true(is.numeric(preds))
    expect_equal(length(preds), nrow(dt))
  })
})


# =============================================================================
# predict.mb_seq — return_all = TRUE
# =============================================================================

describe("predict.mb_seq — return_all = TRUE", {
  df  <- make_df()
  mb1 <- make_mb("pred_a")
  mb2 <- make_mb("pred_b", target ~ x2)
  seq1 <- mb_seq(
    mb_layer(
      blueprints   = list(mb1, mb2),
      yhat_name    = "pred_combined",
      aggregate_fn = function(df) {
        df[["pred_combined"]] <- df[["pred_a"]] + df[["pred_b"]]
        df
      }
    )
  )

  it("returns a data frame", {
    expect_true(is.data.frame(predict(seq1, df, return_all = TRUE)))
  })

  it("does not include original feature or target columns", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_false(any(c("x1", "x2", "target") %in% names(result)))
  })

  it("includes blueprint yhat_name columns", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_true("pred_a" %in% names(result))
    expect_true("pred_b" %in% names(result))
  })

  it("includes the layer yhat_name column", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_true("pred_combined" %in% names(result))
  })

  it("has the same number of rows as the input", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_equal(nrow(result), nrow(df))
  })

  it("combined column equals the sum of the two blueprint predictions", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_equal(result[["pred_combined"]], result[["pred_a"]] + result[["pred_b"]])
  })
})


# =============================================================================
# predict.mb_seq — sequential layers
# =============================================================================

describe("predict.mb_seq — sequential layers", {
  it("layer 2 can reference layer 1's prediction as a feature", {
    df   <- make_df()
    mb1  <- make_mb("pred_layer1")
    df2  <- df
    df2[["pred_layer1"]] <- predict(mb1@model, df)
    mb2  <- modelblueprint(
      model     = lm(target ~ pred_layer1, data = df2),
      train     = df2,
      y_name    = "target",
      yhat_name = "pred_layer2"
    )
    seq2 <- mb_seq(
      mb_layer(list(mb1)),
      mb_layer(list(mb2))
    )
    result <- predict(seq2, df, return_all = TRUE)
    expect_true("pred_layer1" %in% names(result))
    expect_true("pred_layer2" %in% names(result))
    expect_true(all(is.finite(result[["pred_layer2"]])))
  })

  it("intermediate columns don't bleed into return_all = FALSE output", {
    df   <- make_df()
    mb1  <- make_mb("pred_layer1")
    df2  <- df
    df2[["pred_layer1"]] <- predict(mb1@model, df)
    mb2  <- modelblueprint(
      model     = lm(target ~ pred_layer1, data = df2),
      train     = df2,
      y_name    = "target",
      yhat_name = "pred_layer2"
    )
    seq2  <- mb_seq(mb_layer(list(mb1)), mb_layer(list(mb2)))
    preds <- predict(seq2, df)
    expect_true(is.numeric(preds))
    expect_equal(length(preds), nrow(df))
  })
})


# =============================================================================
# predict.mb_seq — error handling
# =============================================================================

describe("predict.mb_seq — error handling", {
  it("gives an informative error when aggregate_fn errors", {
    df   <- make_df()
    seq1 <- mb_seq(
      mb_layer(
        blueprints   = list(make_mb("pred_a"), make_mb("pred_b")),
        yhat_name    = "pred_out",
        aggregate_fn = function(df) stop("intentional failure")
      )
    )
    expect_error(predict(seq1, df), "Layer 1")
  })

  it("errors when aggregate_fn returns a non-data-frame", {
    df   <- make_df()
    seq1 <- mb_seq(
      mb_layer(
        blueprints   = list(make_mb("pred_a"), make_mb("pred_b")),
        yhat_name    = "pred_out",
        aggregate_fn = function(df) 42  # returns a scalar, not a data frame
      )
    )
    expect_error(predict(seq1, df), "data frame")
  })
})


# =============================================================================
# print methods
# =============================================================================

describe("print methods", {
  it("prints mb_layer without error", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_no_error(print(layer))
  })

  it("prints mb_layer with multiple blueprints without error", {
    layer <- mb_layer(
      blueprints   = list(make_mb("pred_a"), make_mb("pred_b", target ~ x2)),
      yhat_name    = "pred_combined",
      aggregate_fn = function(df) {
        df[["pred_combined"]] <- df[["pred_a"]] + df[["pred_b"]]
        df
      }
    )
    expect_no_error(print(layer))
  })

  it("prints mb_seq without error", {
    seq1 <- mb_seq(
      mb_layer(
        blueprints   = list(make_mb("pred_a"), make_mb("pred_b")),
        aggregate_fn = function(df) {
          df[["pred_combined"]] <- df[["pred_a"]] * 0.5 + df[["pred_b"]] * 0.5
          df
        },
        yhat_name = "pred_combined"
      ),
      mb_layer(list(make_mb("pred_c"))),
      model_display_name = "my_seq"
    )
    expect_no_error(print(seq1))
  })

  it("prints mb_seq with dataset slots without error", {
    df   <- make_df()
    seq1 <- mb_seq(
      mb_layer(list(make_mb("pred_a"))),
      train   = df,
      test    = df,
      holdout = df,
      model_display_name = "my_seq"
    )
    expect_no_error(print(seq1))
  })
})
