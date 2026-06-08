# test-mb_seq.R

library(testthat)
library(data.table)

# =============================================================================
# Fixtures
# =============================================================================

make_df <- function(n = 100L) {
  data.frame(
    x1 = seq(1, 10, length.out = n),
    x2 = seq(0.1, 1, length.out = n),
    target = seq(0.5, 5, length.out = n),
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
# mb_layer — construction
# =============================================================================

describe("mb_layer — construction", {
  it("constructs with a single blueprint and no aggregate_fn", {
    layer <- mb_layer(list(make_mb("pred_a")), yhat_name = "pred_a")
    expect_s3_class(layer, "mb_layer")
  })

  it("defaults aggregate_fn to pass-through for a single blueprint", {
    mb <- make_mb("pred_a")
    layer <- mb_layer(list(mb), yhat_name = "pred_a")
    df <- make_df()
    df[["pred_a"]] <- 1:nrow(df)
    expect_equal(layer$aggregate_fn(df), df)
  })

  it("constructs with multiple blueprints and explicit aggregate_fn", {
    layer <- mb_layer(
      blueprints = list(make_mb("pred_a"), make_mb("pred_b", target ~ x2)),
      yhat_name = "pred_combined",
      aggregate_fn = function(df) df[["pred_a"]] + df[["pred_b"]]
    )
    expect_s3_class(layer, "mb_layer")
  })

  it("errors when blueprints is empty", {
    expect_error(mb_layer(list(), yhat_name = "x"), "non-empty")
  })

  it("errors when multiple blueprints and no aggregate_fn", {
    expect_error(
      mb_layer(list(make_mb("a"), make_mb("b")), yhat_name = "c"),
      "aggregate_fn"
    )
  })

  it("errors when a blueprint has no yhat_name", {
    mb_no_yhat <- modelblueprint(
      model = lm(target ~ x1, data = make_df()),
      y_name = "target"
    )
    expect_error(mb_layer(list(mb_no_yhat), yhat_name = "pred"), "yhat_name")
  })

  it("yhat_name defaults to blueprint yhat_name for a single blueprint", {
    layer <- mb_layer(list(make_mb("pred_a")))
    expect_equal(layer$yhat_name, "pred_a")
  })
})

# =============================================================================
# mb_seq — construction
# =============================================================================

describe("mb_seq — construction", {
  it("constructs with a single layer", {
    seq1 <- mb_seq(mb_layer(list(make_mb("pred_a")), yhat_name = "pred_a"))
    expect_true(inherits(seq1, "modelblueprint::mb_seq"))
  })

  it("constructs with multiple layers", {
    seq2 <- mb_seq(
      mb_layer(list(make_mb("pred_a")), yhat_name = "pred_a"),
      mb_layer(list(make_mb("pred_b")), yhat_name = "pred_b"),
      model_display_name = "test_seq"
    )
    expect_true(inherits(seq2, "modelblueprint::mb_seq"))
    expect_equal(seq2@model_display_name, "test_seq")
  })

  it("errors when no layers are supplied", {
    expect_error(mb_seq(), "mb_layer")
  })

  it("errors when layers contains non-mb_layer elements", {
    expect_error(mb_seq("not_a_layer"), "mb_layer")
  })
})

# =============================================================================
# predict.mb_seq — return_all = FALSE (default)
# =============================================================================

describe("predict.mb_seq — returns a numeric vector by default", {
  df <- make_df()
  seq1 <- mb_seq(mb_layer(list(make_mb("pred_a")), yhat_name = "pred_a"))

  it("returns a numeric vector", {
    preds <- predict(seq1, df)
    expect_true(is.numeric(preds))
  })

  it("returns one value per row", {
    preds <- predict(seq1, df)
    expect_equal(length(preds), nrow(df))
  })

  it("predictions are finite", {
    preds <- predict(seq1, df)
    expect_true(all(is.finite(preds)))
  })

  it("errors when newdata is missing", {
    expect_error(predict(seq1), "newdata")
  })
})

# =============================================================================
# predict.mb_seq — return_all = TRUE
# =============================================================================

describe("predict.mb_seq — return_all = TRUE", {
  df <- make_df()
  mb1 <- make_mb("pred_a")
  mb2 <- make_mb("pred_b", target ~ x2)
  seq1 <- mb_seq(
    mb_layer(
      blueprints = list(mb1, mb2),
      yhat_name = "pred_combined",
      aggregate_fn = function(df) {
        df[["pred_combined"]] <- df[["pred_a"]] + df[["pred_b"]]
        df
      }
    )
  )

  it("returns a data frame", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_true(is.data.frame(result))
  })

  it("only prediction columns are returned", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_false(any(c("x1", "x2", "target") %in% names(result)))
  })

  it("blueprint yhat_name columns are appended", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_true("pred_a" %in% names(result))
    expect_true("pred_b" %in% names(result))
  })

  it("layer yhat_name column is appended", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_true("pred_combined" %in% names(result))
  })

  it("has the same number of rows as the input", {
    result <- predict(seq1, df, return_all = TRUE)
    expect_equal(nrow(result), nrow(df))
  })
})

# =============================================================================
# predict.mb_seq — sequential layers
# =============================================================================

describe("predict.mb_seq — sequential layers", {
  it("layer 2 can reference layer 1's prediction as a feature", {
    df <- make_df()
    mb1 <- make_mb("pred_layer1")

    # Layer 2's model is trained on a df that includes pred_layer1
    df_with_pred <- df
    df_with_pred[["pred_layer1"]] <- predict(mb1@model, df)
    mb2 <- modelblueprint(
      model = lm(target ~ pred_layer1, data = df_with_pred),
      train = df_with_pred,
      y_name = "target",
      yhat_name = "pred_layer2"
    )

    seq2 <- mb_seq(
      mb_layer(list(mb1), yhat_name = "pred_layer1"),
      mb_layer(list(mb2), yhat_name = "pred_layer2")
    )

    result <- predict(seq2, df, return_all = TRUE)
    expect_true("pred_layer1" %in% names(result))
    expect_true("pred_layer2" %in% names(result))
    expect_true(all(is.finite(result[["pred_layer2"]])))
  })
})

# =============================================================================
# predict.mb_seq — error handling
# =============================================================================

describe("predict.mb_seq — error handling", {
  it("gives an informative error when aggregate_fn fails", {
    df <- make_df()
    seq1 <- mb_seq(
      mb_layer(
        blueprints = list(make_mb("pred_a"), make_mb("pred_b")),
        yhat_name = "pred_out",
        aggregate_fn = function(df) stop("intentional failure")
      )
    )
    expect_error(predict(seq1, df), "Layer 1")
  })
})

# =============================================================================
# print methods
# =============================================================================

describe("print methods", {
  it("prints mb_layer without error", {
    layer <- mb_layer(list(make_mb("pred_a")), yhat_name = "pred_a")
    expect_no_error(print(layer))
  })

  it("prints mb_seq without error", {
    seq1 <- mb_seq(
      mb_layer(
        list(make_mb("pred_a"), make_mb("pred_b")),
        aggregate_fn = function(df) {
          df$pred_a * 0.5 + df$pred_b * 0.5
        },
        yhat_name = "pred_a"
      ),
      mb_layer(
        list(make_mb("pred_c")),
        yhat_name = "pred_c"
      ),
      model_display_name = "my_seq"
    )

    expect_no_error(print(seq1))
  })
})
