# =============================================================================
# profile_main_functions.R
#
# Profiles the main modelblueprint functions on representative, scaled data to
# surface bottlenecks for further optimisation.
#
# Two complementary views are produced for each function:
#   1. bench::mark()  -> median time + memory allocated (overview table)
#   2. Rprof summary  -> top self-time functions (headless hotspot breakdown)
#   3. profvis HTML   -> interactive flame graph saved to profiling/out/
#
# For the aggregation-style functions, both ret = "data" (pure compute) and
# ret = "plot" (compute + plotly assembly) are profiled, so you can see how
# much of the cost is the plotly object construction vs the data work.
#
# Usage
# -----
#   # from the package root, interactively (best — gives clickable flame graphs):
#   source("profiling/profile_main_functions.R")
#
#   # or headless:
#   Rscript profiling/profile_main_functions.R            # default 200k rows
#   Rscript profiling/profile_main_functions.R 1000000    # 1M rows
#
# Notes
# -----
#   * H2O is intentionally skipped (needs a running JVM cluster).
#   * Increase N for a more realistic picture; 200k is a quick smoke profile.
# =============================================================================

# ---- configuration ----------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
N <- if (length(args) >= 1L) as.integer(args[[1]]) else 1000000L
# Extra "noise" columns the model never uses. Real pricing frames are wide
# (dozens-to-hundreds of columns), and the column-narrowing optimisations only
# show their payoff when there are unused columns to avoid copying. Pass a
# second arg to override, e.g. `Rscript ... 1000000 80`.
N_EXTRA <- if (length(args) >= 2L) as.integer(args[[2]]) else 45L
OUTDIR <- file.path("profiling", "out")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

# ---- dependencies -----------------------------------------------------------
need <- c("bench", "data.table")
have_profvis <- requireNamespace("profvis", quietly = TRUE)
for (p in need) {
  if (!requireNamespace(p, quietly = TRUE)) {
    stop(sprintf("Please install '%s' to run the profiler.", p), call. = FALSE)
  }
}
if (!have_profvis) {
  message(
    "profvis not installed — skipping flame-graph HTML (Rprof summary still runs)."
  )
}

# ---- load the package -------------------------------------------------------
# Prefer the in-development source so you profile your working tree.
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(modelblueprint)
}

set.seed(1L)

# =============================================================================
# Synthetic, pricing-shaped dataset
# =============================================================================
# A mix of: continuous, integer, low- and high-cardinality categoricals, a date
# column, an exposure column with genuine variation, and a target with signal.
message(sprintf(
  "Building synthetic data: %s rows ...",
  format(N, big.mark = ",")
))

make_data <- function(n, n_extra = 0L) {
  region <- factor(sample(LETTERS[1:8], n, replace = TRUE))
  vehicle <- factor(sample(sprintf("veh_%02d", 1:40), n, replace = TRUE)) # high card
  age <- sample(18:85, n, replace = TRUE)
  bm <- round(rnorm(n, 50, 15), 2)
  power <- round(rgamma(n, shape = 2, scale = 30))
  start <- as.Date("2019-01-01") + sample(0:1825, n, replace = TRUE)
  expo <- round(runif(n, 0.05, 1), 3)

  # Target: a frequency-like rate with signal from age, bm, region.
  lin <- -2 + 0.012 * (age - 50) + 0.008 * (bm - 50) + as.numeric(region) * 0.03
  rate <- plogis(lin)
  claims <- rbinom(n, size = 1L, prob = pmin(rate, 0.95))

  base <- data.frame(
    age = age,
    bm = bm,
    power = power,
    region = region,
    vehicle = vehicle,
    start = start,
    exposure = expo,
    claims = claims,
    stringsAsFactors = FALSE
  )

  # Append unused "noise" columns to widen the frame. A few are factors to
  # mimic the categorical clutter of a real rating dataset; the rest numeric.
  # None appear in the model formula, so they only ever exist to be (not) copied.
  if (n_extra > 0L) {
    extra <- vector("list", n_extra)
    names(extra) <- sprintf("noise_%02d", seq_len(n_extra))
    n_fac <- min(5L, n_extra)
    for (j in seq_len(n_extra)) {
      extra[[j]] <- if (j <= n_fac) {
        factor(sample(letters[1:6], n, replace = TRUE))
      } else {
        rnorm(n)
      }
    }
    base <- cbind(base, as.data.frame(extra, stringsAsFactors = FALSE))
  }
  base
}

df <- make_data(N, N_EXTRA)
message(sprintf(
  "Frame: %s rows x %d columns (%d unused noise columns).",
  format(N, big.mark = ","),
  ncol(df),
  N_EXTRA
))

# A cheap, fast-to-predict model so the profile reflects modelblueprint's own
# overhead rather than the model's predict() cost.
model <- glm(
  claims ~ age + bm + power + region,
  data = df,
  family = binomial,
  weights = exposure
)

mb <- modelblueprint(
  model = model,
  train = df,
  y_name = "claims",
  x_original_inputs = c("age", "bm", "power", "region", "vehicle"),
  expo_name = "exposure",
  model_display_name = "freq_glm"
)

# =============================================================================
# Helpers
# =============================================================================

# Run an expression under Rprof and print the top self-time entries. This is the
# headless hotspot view — it answers "which functions burned the most time".
rprof_top <- function(label, expr, n = 15L, interval = 0.005) {
  tf <- tempfile(fileext = ".out")
  Rprof(tf, interval = interval, line.profiling = TRUE, memory.profiling = TRUE)
  res <- tryCatch(force(expr), error = function(e) e)
  Rprof(NULL)
  cat("\n==== Rprof:", label, "====\n")
  if (inherits(res, "error")) {
    cat("  ERROR:", conditionMessage(res), "\n")
    return(invisible(NULL))
  }
  s <- summaryRprof(tf, memory = "none")
  by_self <- head(s$by.self[order(-s$by.self$self.pct), , drop = FALSE], n)
  print(by_self)
  cat(sprintf("  total sampled time: %.3fs\n", s$sampling.time))
  unlink(tf)
  invisible(s)
}

# Save an interactive flame graph if profvis is available.
save_profvis <- function(name, expr) {
  if (!have_profvis) {
    return(invisible(NULL))
  }
  pv <- profvis::profvis(force(expr))
  out <- file.path(OUTDIR, paste0("profvis_", name, ".html"))
  htmlwidgets::saveWidget(pv, out, selfcontained = TRUE)
  cat("  flame graph ->", out, "\n")
  invisible(out)
}

# =============================================================================
# 1. Overview: bench::mark timing + memory for every main entry point
# =============================================================================
message("\nRunning bench::mark overview (this is the headline table) ...")

bm_overview <- bench::mark(
  predict = predict(mb, df),
  one_way_data = one_way(mb, var = "age", ret = "data"),
  one_way_plot = one_way(mb, var = "age", ret = "plot"),
  one_way_pred = one_way(mb, var = "age", predictions = TRUE, ret = "data"),
  one_way_split = one_way(mb, var = "age", split = "region", ret = "data"),
  one_way_highcard = one_way(mb, var = "vehicle", ret = "data"),
  one_way_date = one_way(mb, var = "start", time_unit = "month", ret = "data"),
  pdp_data = pdp(mb, var = "age", ret = "data"),
  pdp_plot = pdp(mb, var = "age", ret = "plot"),
  gain = gain(mb, ret = "data"),
  pred_vs_obs = pred_vs_obs(mb, ret = "data"),
  residuals_grouped = residuals_grouped(mb, ret = "data"),
  shap_importance = shap(
    mb,
    vars = c("age", "bm"),
    nsim = 10L,
    sample_size = 500L,
    ret = "data"
  ),
  iterations = 5L,
  check = FALSE,
  filter_gc = FALSE
)

cat("\n================ bench::mark overview ================\n")
print(bm_overview[, c("expression", "median", "mem_alloc", "n_gc")])

# =============================================================================
# 2. Hotspot breakdown (Rprof) for the heavier functions
# =============================================================================
message("\nRunning Rprof hotspot breakdowns ...")

rprof_top("one_way (plot)", one_way(mb, var = "age", ret = "plot"))
rprof_top(
  "one_way (split, plot)",
  one_way(mb, var = "age", split = "region", ret = "plot")
)
rprof_top("pdp (plot)", pdp(mb, var = "age", ret = "plot"))
rprof_top("gain", gain(mb))
rprof_top("pred_vs_obs", pred_vs_obs(mb))
rprof_top("residuals_grouped", residuals_grouped(mb))
rprof_top(
  "shap importance",
  shap(mb, vars = c("age", "bm"), nsim = 20L, sample_size = 1000L)
)

# =============================================================================
# 3. Interactive flame graphs (profvis -> HTML) for the worst offenders
# =============================================================================
if (have_profvis && requireNamespace("htmlwidgets", quietly = TRUE)) {
  message("\nSaving profvis flame graphs to ", OUTDIR, " ...")
  save_profvis("one_way", one_way(mb, var = "age", ret = "plot"))
  save_profvis("pdp", pdp(mb, var = "age", ret = "plot"))
  save_profvis(
    "shap",
    shap(mb, vars = c("age", "bm"), nsim = 20L, sample_size = 1000L)
  )
  save_profvis("residuals_grouped", residuals_grouped(mb))
} else {
  message("\nInstall 'profvis' and 'htmlwidgets' for interactive flame graphs.")
}

cat(
  "\nDone. Open the HTML files in profiling/out/ for clickable flame graphs,\n"
)
cat("and read the Rprof tables above for the headless hotspot view.\n")
