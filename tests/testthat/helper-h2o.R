# H2O test helpers — loaded by testthat before any test file runs.

# Start H2O, skipping the test if the cluster can't be reached.
# Wrapping h2o.init() in tryCatch converts port conflicts, severed connections,
# and JVM failures into skips rather than test failures.
h2o_init_safe <- function() {
  skip_if_not_installed("h2o")
  ok <- tryCatch({
    suppressWarnings(suppressMessages(h2o::h2o.init(nthreads = 1L)))
    TRUE
  }, error = function(e) FALSE)
  if (!ok || !h2o::h2o.clusterIsUp()) {
    skip("H2O cluster is not available — skipping (not a code failure).")
  }
  h2o::h2o.no_progress()
}

# Shut down H2O and poll until the JVM has actually released the port.
# A fixed Sys.sleep(12) is unreliable: sometimes the JVM takes longer,
# causing the next h2o.init() to hit a port conflict. Polling (max 30s)
# is both faster when shutdown is quick and correct when it isn't.
h2o_shutdown_safe <- function() {
  tryCatch(
    suppressMessages(h2o::h2o.shutdown(prompt = FALSE)),
    error = function(e) NULL
  )
  for (i in seq_len(30L)) {
    Sys.sleep(1L)
    still_up <- tryCatch(h2o::h2o.clusterIsUp(), error = function(e) FALSE)
    if (!still_up) break
  }
  invisible(NULL)
}
