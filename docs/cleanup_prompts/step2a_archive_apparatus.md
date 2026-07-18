# Step 2a prompt for Claude Code (Sonnet) — Archive finished blind-phase apparatus

> Paste the fenced block below into Claude Code, on branch `feature/step3d-live-feedback-self-test`,
> from a clean tree that is green at 205/205 (Step 1 done, tag `pre-refactor-2026-07-18`).
> This moves the finished filter-decision / artificial-simulation apparatus into `dev-archive/` via
> `git mv`, edits the hardcoded test list in `tests/run_all_tests.m`, and lands it all in ONE commit.
> A read-only dependency/path preflight (Phase 0) runs before anything is created or moved.
>
> The keep/move lists were verified against the repo by dependency trace AND by a "what contract does
> this test protect" review (none of the 24 movers drives the active filter/power primitives). Do not
> expand or shrink the lists; Phase 0 re-verifies them in-repo.

```text
Step 2a: Archive the finished blind-phase validation/simulation apparatus into dev-archive/.

PURPOSE
Read CLAUDE.md and CLEANUP_MANIFEST.md. The filter-method decision (IIR/SOS) and the artificial-
simulation validation work are finished. Relocate that apparatus off the default path into dev-archive/,
preserving git history. Do NOT touch the Frozen Step 0 harness or Step 3D code — those are active.
This step is relocation only, plus one required edit to tests/run_all_tests.m and one new README.

PRECONDITIONS (verify; STOP if any fails)
- git branch --show-current == feature/step3d-live-feedback-self-test
- git status --short --branch --untracked-files=all shows a CLEAN tree
- tag pre-refactor-2026-07-18 exists
- Open tests/run_all_tests.m and confirm the printed count comes from numel() of the hardcoded `tests`
  cell list (i.e. 1 list entry == 1 reported test). Confirm that list currently has exactly 205 entries.
  If the printed count and list length use different semantics, STOP and explain before relying on 205-24=181.
- Baseline green: run  matlab -batch "cd tests; run_all_tests()"  -> "All 205 tests passed."
  (If MATLAB is unavailable, STOP — do not proceed blind.)

HARD CONSTRAINTS
- Never git push / create / switch branches / amend / rebase / reset --hard / clean.
- Relocate with `git mv` only; never copy-and-delete. Verify renames as R100 (see Phase F).
- Move ONLY files in the MOVE lists. Never move a KEEP-EXCEPTIONS file.
- Do not modify the contents of any moved file. Apart from creating the new dev-archive/README.md, the
  only edit to an existing tracked file permitted this step is removing the 24 archived test names from
  tests/run_all_tests.m.
- Never manually modify, stage, delete, clean, or commit anything under outputs/ or logs/. Test runs may
  create ignored files there; that is permitted, but do not stage, delete, inspect-for-cleanup, or commit
  them. Capture `git status --porcelain=v1 --untracked-files=all` immediately before and after each test
  run and report any tracked or non-ignored change the run introduced.
- Stop and ask on any ambiguity, missing path, or count mismatch.

MOVE LIST — 27 SOURCE files (destination preserves the subfolder under dev-archive/):
  validation/ -> dev-archive/validation/ (12):
    nf_apply_offline_brainstorm_bandpass.m  nf_apply_offline_iir_sos.m  nf_compute_offline_window_power.m
    nf_make_offline_reference.m  nf_make_synthetic_theta_dataset.m  nf_validate_band_detection.m
    nf_validate_brainstorm_vs_streaming.m  nf_validate_empirical_filter_delay.m  nf_validate_fft_comparison.m
    nf_validate_filter_runtime.m  nf_validate_iir_sos_comparison.m  nf_validate_theta_recovery.m
  analysis/ -> dev-archive/analysis/ (7):
    nf_baseline_to_table.m  nf_make_marc_validation_report.m  nf_plot_synthetic_input_report.m
    nf_plot_trial_report.m  nf_plot_validation_report.m  nf_synthetic_block_info_to_table.m  nf_validation_to_table.m
  main/ -> dev-archive/main/ (4):
    nf_run_validation.m  nf_run_marc_validation_bundle.m  nf_run_brainstorm_iir_sos_check.m  nf_run_brainstorm_intro_validation.m
  config/ -> dev-archive/config/ (1):  nf_brainstorm_intro_validation_config.m
  io/ -> dev-archive/io/ (2):  nf_export_brainstorm_ctf_to_validation_mat.m  nf_save_validation_results.m
  temp/ -> dev-archive/temp/ (1):  inspect_brainstorm_intro_results.m

MOVE LIST — 24 TEST files -> dev-archive/tests/:
  test_band_detection_synthetic_positive.m  test_band_detection_wrong_band_control.m  test_baseline_to_table.m
  test_brainstorm_iir_sos_bst_function_synthetic.m  test_brainstorm_intro_real_iir_sos_comparison_if_available.m
  test_brainstorm_intro_validation_config.m  test_brainstorm_intro_validation_config_enables_bst_function.m
  test_brainstorm_missing_skips_cleanly.m  test_fft_comparison_detects_injected_theta.m
  test_fft_comparison_sample_range_mapping.m  test_iir_sos_comparison_self_reference.m
  test_marc_report_includes_synthetic_input_metadata.m  test_marc_validation_bundle_smoke.m
  test_marc_validation_report_generation.m  test_offline_reference_stepped_matches_dense.m
  test_run_validation_segment_bounds_not_double_applied.m  test_synthetic_input_report_generation.m
  test_synthetic_theta_dataset.m  test_synthetic_theta_recovery.m  test_trial_report_generation.m
  test_validation_alignment_uses_uncorrected_samples.m  test_validation_report_generation.m
  test_validation_to_table.m  test_wrong_band_control_rejected.m

KEEP-EXCEPTIONS — verified still-needed; DO NOT move:
  io/nf_load_validation_data.m            (real dataset loader used by nf_run_resting / nf_run_trial)
  analysis/nf_measures_to_table.m         (used by the live logger)
  analysis/nf_save_development_session_report.m  (Step 0 harness report)
  validation/nf_validate_dropped_chunk_behavior.m  (core dropped-chunk coverage)
  tests/test_fs_mismatch_errors.m         (tests the kept loader)
  tests/test_deterministic_dropped_chunk_simulation.m   (core dropped-chunk behavior)
  tests/test_validate_dropped_chunk_behavior.m          (core dropped-chunk behavior)

PHASE 0 — archive-boundary preflight (READ-ONLY; make no changes)
1. Verify every MOVE-list source path (27 + 24) exists exactly once, and every intended dev-archive/
   destination path does NOT already exist.
2. Verify no MOVE-list path appears in KEEP-EXCEPTIONS and no KEEP-EXCEPTION path appears in a MOVE list.
3. For each of the 27 functions being archived, search the whole repo for references. Classify each:
     A. inside a file that is itself being archived;
     B. docs / comments / CLEANUP_MANIFEST.md / historical text;
     C. active source, config, path bootstrap, or a test that will REMAIN outside dev-archive/.
   If ANY category-C reference exists, STOP and report caller, referenced function, line/context, and why
   it may still be active. In particular confirm every KEEP-EXCEPTION file and all Frozen Step 0 / Step 3D
   files have no runtime dependency on an archived function.
   (Expected, already known and allowed: nf_run_resting.m / nf_run_trial.m mention nf_run_validation only
   in comments — confirm it is comment-only, not a call.)
4. Contract check on the 24 test movers: a test must REMAIN active if it protects any behavior still used
   by the production-equivalent simulation or live pipeline, even if its fixtures are synthetic. Archive a
   test only if it exercises archived validation entry points rather than an active computational primitive
   (e.g. nf_rt_filter_apply / nf_rt_compute_power / nf_rt_process_chunk). If any mover directly validates an
   active primitive, STOP and flag it.
5. Inspect ALL path-setup mechanisms (nf_add_paths.m, startup.m, any addpath/genpath/pathdef/recursive
   root add, and how tests are discovered). Confirm the normal app+test path will NOT include dev-archive/.
   If any generic recursive path addition would include it, STOP.
6. Run  git check-ignore -v dev-archive/README.md . If it would be ignored, STOP and report the rule.
Report findings. Make no changes.
[CONFIRM]

PHASE A — create dev-archive skeleton
Create dev-archive/{validation,analysis,main,config,io,temp,tests}/ and dev-archive/README.md noting:
"Finished blind-phase apparatus (filter-method decision + artificial-simulation validation). Archived
2026-07-18, off the default path, not shipped. See CLEANUP_MANIFEST.md."
[CONFIRM]

PHASE B — git mv the 27 source files. Show `git status --short`. Confirm exactly 27 renames, none from
KEEP-EXCEPTIONS.
[CONFIRM]

PHASE C — git mv the 24 test files to dev-archive/tests/. Confirm exactly 24, and that the 3 KEEP-EXCEPTION
tests are NOT among them.
[CONFIRM]

PHASE D — edit tests/run_all_tests.m
Before editing: locate the hardcoded `tests` cell; verify each of the 24 archived test names appears
EXACTLY ONCE in it, and each of the 3 KEEP-EXCEPTION test names appears exactly once and will remain. If any
archived name is missing or duplicated, STOP.
Edit: remove exactly the 24 archived names. Change nothing else.
After editing: verify none of the 24 remain in the active list, all 3 KEEP-EXCEPTIONS remain, no other entry
changed, and the list length decreased by exactly 24 (205 -> 181). Show the diff (24 deletions, 0 additions).
[CONFIRM]

PHASE E — verify green at the new baseline
Run  matlab -batch "cd tests; run_all_tests()" . Expect "All 181 tests passed." Report the exact number.
If not exactly 181, or any failure, or any "undefined function" error, STOP and do not commit. Report the
before/after `git status --porcelain=v1 --untracked-files=all` and confirm the run modified no tracked files.
[CONFIRM]

PHASE F — commit (single atomic commit; allowlist verification, not just counts)
Stage only: the 27 source renames, the 24 test renames, tests/run_all_tests.m, and dev-archive/README.md.
Run:
  git diff --cached --name-status --find-renames=100%
  git diff --cached --stat
  git diff --cached --check
Required staged shape:
  - exactly 51 R100 entries (27 source + 24 test), each source on a MOVE list and each destination
    preserving the specified relative subfolder;
  - exactly 1 M entry: tests/run_all_tests.m;
  - exactly 1 A entry: dev-archive/README.md.
Verify: no KEEP-EXCEPTION path appears; no Frozen Step 0 / Step 3D path appears except tests/run_all_tests.m;
nothing under outputs/ or logs/; no moved file has a content change; `--check` reports no whitespace errors.
If any condition fails, STOP.
Commit: `Archive finished blind-phase validation/simulation apparatus to dev-archive/`
Report HEAD and git status (clean).

PHASE G — final report (derive claims from the diff, not from passing tests)
From the parent->HEAD commit diff, confirm the ONLY changed paths are the 51 relocation pairs,
tests/run_all_tests.m, and dev-archive/README.md. Explicitly report that no other Frozen Step 0 or Step 3D
file changed. Report: commit hash, moved counts by folder, run_all_tests result (181), tree clean.
Do NOT start the big-file splits — that is Step 2b.
```
