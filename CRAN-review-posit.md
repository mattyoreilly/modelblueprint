# modelblueprint — code review toward CRAN

*A read-through by Hadley & the Posit team. Ordered most-important first. The
top tier are things that will get the package bounced from CRAN; the lower tiers
are robustness, design, and polish.*

First, the good news so you know where you stand: this is a genuinely
well-built package. The S7 object model is thoughtful, the data.table
aggregation is written to keep GForce alive, the defensive copying is correct,
the binning primitives are shared rather than duplicated across `one_way()` /
`pdp()` / `shap()`, and the test suite (~200 `it()` blocks, ~8,800 lines, with
`skip_on_cran` / `skip_if_not_installed` used properly) is better than most
packages arrive with. The work below is mostly about clearing CRAN's gate and
tightening a handful of edges.

---

## Tier 1 — CRAN blockers (the submission will be rejected without these)

1. **Invalid author metadata.** `DESCRIPTION` has
   `person("Hubert", "Ratajczyk", ... email = "jane@example.com")` — a
   placeholder address — and `person("Matt", role = c("aut","cre"))` with no
   family name. CRAN's incoming checks reject placeholder emails and require a
   real, identifiable maintainer name. Fix both, and add a copyright holder
   (`role = "cph"`) and ideally ORCIDs.

2. **`set.seed()` inside exported functions.** `.mb_split()`, `.car_freq_split()`
   and `.mb_large_split()` all call `set.seed(seed)`, and they run from the
   exported `mb_lm_regression()`, `mb_glm_*()`, etc. That silently clobbers the
   *user's* global RNG stream — an explicit CRAN policy violation. You already
   use `withr::with_seed()` correctly in `pdp()`/`shap()`; do the same here (or
   `withr::with_preserve_seed()`).

3. **Non-ASCII in `DESCRIPTION`.** Line 14 of the `Description` contains a
   literal em dash (`—`). `R CMD check` flags non-ASCII in `DESCRIPTION`; replace
   with `--` or `—`-free wording. (Box-drawing characters litter the R
   comments too — see Tier 4 — but the `DESCRIPTION` one is the hard stop.)

4. **No `R CMD check` CI, and the badge is broken.** `.github/workflows/` only
   has `pkgdown.yaml`. The README badge points at
   `github.com/matt/modelblueprint` while the real remote is
   `mattyoreilly/modelblueprint`, so it 404s. Add the standard check workflow
   (`usethis::use_github_action("check-standard")`) and fix the badge URL. You
   want green checks on three platforms before you submit, not after.

5. **`\dontrun{}` overuse on runnable examples.** Eight files wrap examples in
   `\dontrun{}` (`one_way`, `pdp`, `gain`, `pred_vs_obs`, `residuals_grouped`,
   `sami`, the `modelblueprint()` constructor…). Most of these run fine on
   `mtcars` + `lm`/`glm` in well under 5s. CRAN reviewers specifically push back
   on `\dontrun` for code that *can* run — it reads as "this example is broken."
   Use real examples or `\donttest{}`; reserve `\dontrun{}` for the genuinely
   un-runnable ones (H2O cluster, `mb_dashboard()`'s Shiny app). `shap()`
   already gets this right with `\donttest{}`.

6. **Missing standard metadata files.** No `NEWS.md`, no `BugReports:` field, no
   `Config/testthat/edition: 3` (your tests assume 3e behaviour). Add all three;
   CRAN and your users both expect them.

---

## Tier 2 — Robustness & correctness

7. **Wholesale `import()`s.** The package does `import(data.table)`,
   `import(plotly)`, `import(RColorBrewer)`, `import(S7)`. Importing entire
   namespaces invites masking collisions (data.table and dplyr both define
   `:=`, `first`, `last`, `between`) and bloats the NAMESPACE. `RColorBrewer` is
   imported wholesale for the single function `brewer.pal`. Prefer
   `@importFrom` for the symbols you actually use; keep a full `import()` only
   where the NSE genuinely needs it (data.table), and even there many teams
   scope it down.

8. **Hand-rolled S7↔S3 method registration in `.onLoad()`.** You register ~40
   methods under the package-qualified string `"modelblueprint::modelblueprint"`
   via `registerS3method()`, and define `print`/`predict` *twice* (an S3 method
   and an S7 `method()`) to cover the installed-vs-`load_all()` paths. It works,
   but it's fragile and will surprise the next maintainer. This is exactly the
   problem `S7::methods_register()` plus the documented external-generic pattern
   is meant to solve — move to it if you can, and either way add a test that
   exercises dispatch under both `library()` and `pkgload::load_all()` so a
   future S7 change can't silently break it.

9. **Division-by-zero in hover text.** `plot_one_way_simple()` computes
   `(y_vals - y_ref) / y_ref`, `plot_pdp()` computes
   `(pred_mean - obs_mean)/obs_mean` and `(pdp_mean - global_pred)/global_pred`.
   When the reference mean is 0 these become `Inf`/`NaN` and leak into the
   tooltip. Guard with a small denominator floor or suppress the % when the base
   is ~0.

10. **H2O multinomial path is wrong.** In `model_predict()`, when there is no
    `"p1"` column you fall through to `as.numeric(raw[[1L]])` — for a
    multinomial model column 1 is the predicted *class label* (a factor), so
    `as.numeric()` returns integer level codes, not a probability. Either handle
    multinomial explicitly or error clearly that it's unsupported. (Binomial and
    regression are fine.)

11. **Console noise on every call.** `pdp.default()` fires
    `cli_alert_info("Calculating pdp for …")` and `aggregate_one_way()` calls
    `message()` for NA rows on *every* invocation. Inside `model_validation()`
    and the dashboard these loop over every feature, producing a wall of
    messages. Add a `verbose` argument (or use `rlang::inform(.frequency=)`) and
    default it down.

12. **Non-reproducible stability split.** `model_validation()`'s stability plot
    does `sample(c("A","B"), …)` with no seed — the "is this pattern stable?"
    diagnostic changes every run. Seed it (`withr::with_seed`) or expose a seed
    argument. (Mirror image of point 2: here you *want* determinism and don't
    have it.)

13. **`savemb()` temp-dir collision risk.** The scratch directory is named with
    `as.integer(Sys.time())` (one-second resolution). Two saves in the same
    second collide. Use `tempfile()` for the directory name. Also prefer `cli`
    over the bare `message()` for the "saved" notice, for consistency.

---

## Tier 3 — Design & consistency

14. **Constructor is undocumented at the call site.** `modelblueprint()` is
    declared with `@usage NULL` and only a `\dontrun{}` example, so the help page
    never shows how to actually construct one. This is the package's front door
    — give it a visible usage and a runnable example.

15. **Inconsistent default prediction-column names.** The prediction column is
    named `"model_pred"` in `gain.modelblueprint()`, `"pred"` in
    `pred_vs_obs`/`residuals_grouped`, and `.pred_<name>` in `resolve_obs()`.
    Harmonise on one convention (`.pred_<display_name>` reads best) so
    `ret = "data"` output is predictable across functions.

16. **Committed build artifacts.** `doc/`, `Meta/`, and `docs/` are checked into
    the repo. They're correctly `.Rbuildignore`d, but they shouldn't be in
    version control — they go stale and bloat diffs. Git-ignore them and let the
    pkgdown workflow publish the site.

17. **README polish.** Fix the badge owner, the install string already says
    `mattyoreilly` (good) but the badge says `matt` — make them agree, and drop
    the em dash for consistency with an ASCII-clean source.

18. **Add a spelling check.** `usethis::use_spell_check()` + a `WORDLIST` will
    catch the actuarial vocabulary (SAMI, Hosmer, GForce…) before a reviewer
    does, and it's one more clean check in your favour.

---

## Tier 4 — Polish

19. **Non-ASCII in R sources.** `zzz.R` (38), `modelblueprint.R` (12),
    `model_validation.R` (11) and others use box-drawing characters (`──`, `✓`)
    in comments and a few headers. Harmless with `Encoding: UTF-8`, but some CRAN
    reviewers ask for ASCII-only source. You already use `\uXXXX` escapes nicely
    in `dashboard.R`'s strings — worth applying the same discipline to comments.

20. **`plot_gain()` colour cap.** `RColorBrewer::brewer.pal(max(3L, n), "Paired")`
    errors for `n > 12` competing scores. Unlikely, but a `colorRampPalette`
    fallback removes the foot-gun.

21. **Exercise internals through the public API too.** Tests reach into
    `modelblueprint:::trapz` / `:::compute_cumulative`. That's fine for unit
    coverage, but add at least one end-to-end assertion on the public `gain()`
    output so a refactor of the internals can't pass while breaking users.

22. **`return_all` column dedup in `predict.mb_seq()`.** `pred_cols` can collect
    duplicate names when an `aggregate_fn` overwrites a blueprint's column;
    `df[pred_cols]` then returns duplicate columns. A `unique()` tidies it.

---

*Net: Tier 1 is a day or two of metadata and example hygiene and it's the whole
gate. Tiers 2–4 are what take it from "passes check" to "package we'd point
people to." Nicely done so far.*
