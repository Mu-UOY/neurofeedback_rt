# neurofeedback_rt — Cleanup Manifest (keep / archive / split)

Generated 2026-07-18 from the live repo at commit `60da89a` (*Merge Step 3C live RT dry run*).
This is an **execution spec for coding agents** (Claude Code / Codex), not the execution itself.

## Purpose

The program grew across several prototyping stages: a blind-development phase with artificial
simulations to choose a filtering method (decided: **IIR/SOS**), then Step 0 / Step 3x staged
harnesses, then the live FieldTrip path. The scientific core is small and clean; the weight is
prototype-era scaffolding. This manifest classifies every file so the working set handed to
coding agents shrinks ~35% **without losing any function on the path to the goal**.

The partition line is the one that also serves eventual Brainstorm open-source packaging:
**shippable core** (survives, gets published) vs **development apparatus** (archived, never ships).

## Plan context & TIMING CORRECTION (read before archiving)

Two active plans govern the code (both in `docs/`):

- **`Next plan 3.0` — Step 3D live self-test** (`nf_run_live_self_test`). This is the **current branch**
  `feature/step3d-live-feedback-self-test`. Uncommitted WIP on the tree is largely this work.
- **`Neurofeedback_Frozen … v1.0` — full FieldTrip simulation plan.** You are mid-implementing its
  **Step 0: early full-chain orchestration skeleton**, whose stated deliverable is *"an always-running
  full-chain development harness available before the scientific matrix is complete."*

**Correction to this manifest:** the Step 0 harness is **active current-milestone work, NOT legacy to
archive.** These files are therefore **KEEP-ACTIVE (archive later, only after Frozen Step 5 builds the
real matrix and supersedes the skeleton):**
`main/nf_run_development_full_chain.m`, `main/nf_run_development_transition.m`,
`main/nf_development_timeline_init.m`, `main/nf_development_timeline_append.m`,
`main/nf_development_maybe_inject_failure.m`, `main/nf_validate_development_feedback_audit.m`,
and **all `step0_*` tests** (keep as-is for now — the earlier "archive 10 / rewrite 8" split is
deferred until the harness is retired).

**What is still safe to archive now** is only the genuinely-finished *blind-phase* apparatus: the
`validation/` filter-comparison + artificial-simulation suite (the FFT-vs-IIR/SOS decision, now made),
the `marc_validation` reporting, synthetic-theta datasets, and the `brainstorm_intro` / `iir_sos_check`
validation runners. Those predate both current plans and their job is done.

## Ground truth measured from the repo

- 345 `.m` files. Non-test/non-output code: **23,386 lines**. Tests: **210 files / 10,710 lines**.
- Dependency trace result: **nothing in `validation/` or `analysis/` is reached from the production
  path** (`nf_run_resting`, `nf_run_trial`, `nf_run_live_*`). They are called only by the
  validation / marc / brainstorm-intro / development-full-chain entry points.
  - **Only two exceptions** feed real production output and must stay: `analysis/nf_measures_to_table.m`
    (used by `io/nf_logger_close.m` and the live dry-run) and — as a dev-only report —
    `analysis/nf_save_development_session_report.m`.

## The three buckets

- **KEEP-CORE** — the real-time neurofeedback algorithm + live source + config + logging. Untouchable behavior; this is what ships.
- **ARCHIVE-DEV** — prototype/validation/staged-harness apparatus. Move to `dev-archive/` (a folder or a long-lived branch), off the default path. **Not deleted** — it's your intellectual history and the record of why IIR/SOS was chosen.
- **SPLIT** — files that stay (they're core) but are too large and confuse coding agents; decompose under test guard.

---

## KEEP-CORE (ships / survives)

Whole folders — every file kept:

| Folder | Files | Lines | Role |
|---|---|---|---|
| `rt/` | 12 | 1,022 | Chunk pipeline: spatial apply, filter, power, z-score, measure. The heart. |
| `baseline/` | 5 | 416 | Resting baseline accumulate / quality / finalize. |
| `buffer/` | 4 | 213 | Rolling window + gap detection. |
| `feedback/` | 6 | 839 | Circle mapping + Psychtoolbox update. |
| `measure/` | 2 | 139 | Measure schema. |
| `sync/` | 2 | 114 | Timestamp / dropped-chunk sync. |
| `safety/` | 4 | 255 | Stop flags, failsafe, shutdown. |
| `spatial/` | 5 | 914 | CombinedMatrix contract + validation. **Will grow with `compute_live`.** |
| `source/` | 17 | 1,900 | Live FieldTrip adapter, CTF header/corrections, dev replay producer. |

Selected files from mixed folders — KEEP:

**`config/` (keep 10):** `nf_check_config.m` (⇒ also SPLIT), `nf_default_config.m`,
`nf_finalize_config.m`, `nf_live_config.m` (⇒ also SPLIT), `nf_local_fieldtrip_replay_config.m`,
`nf_modes.m`, `nf_project_root.m`, `nf_session_requires_spatial.m`,
`nf_ctf275_primary_channel_names.m`, `nf_step0_provisional_reference_channel_names.m`.

**`io/` (keep 12):** `nf_logger_init/append_measure/append_chunk_meta/close`, `nf_load_baseline`,
`nf_save_baseline`, `nf_save_trial_log`, `nf_save_partial_log`, `nf_make_session_output_dir`,
`nf_save_live_channel_check`, `nf_save_live_chunk_smoke_test`, `nf_save_live_rt_dry_run`,
`nf_save_live_self_test`.

**`main/` (keep 14) — production runners + phase logic:** `nf_run_resting`, `nf_run_trial`,
`nf_run_live_resting` (SPLIT), `nf_run_live_trial` (SPLIT), `nf_run_live_rt_dry_run` (SPLIT),
`nf_run_live_channel_check`, `nf_run_live_chunk_smoke_test` (SPLIT), `nf_run_live_self_test` (SPLIT),
`nf_run_live_diagnostics`, `nf_run_development_transition`, `nf_wait_for_manual_start`,
`nf_determine_stop_reason`, `nf_trial_success_criterion_met`, `nf_start_fieldtrip_file_replay`.

**`analysis/` (keep 2):** `nf_measures_to_table.m` (feeds live logger), `nf_save_development_session_report.m`.

**Root:** `nf_add_paths.m`, `startup.m`, `.gitignore`.

---

## ARCHIVE-DEV → move to `dev-archive/` (off default path, keep in git)

**`validation/` — all 13** (2,931 lines). The filter-method decision apparatus; IIR/SOS is chosen.
`nf_apply_offline_brainstorm_bandpass`, `nf_apply_offline_iir_sos`, `nf_compute_offline_window_power`,
`nf_make_offline_reference`, `nf_make_synthetic_theta_dataset`, `nf_validate_band_detection`,
`nf_validate_brainstorm_vs_streaming`, `nf_validate_dropped_chunk_behavior`,
`nf_validate_empirical_filter_delay`, `nf_validate_fft_comparison`, `nf_validate_filter_runtime`,
`nf_validate_iir_sos_comparison`, `nf_validate_theta_recovery`.

**`analysis/` — archive 7 of 9:** `nf_baseline_to_table`, `nf_make_marc_validation_report`,
`nf_plot_synthetic_input_report`, `nf_plot_trial_report`, `nf_plot_validation_report`,
`nf_synthetic_block_info_to_table`, `nf_validation_to_table`.

**`main/` — archive ONLY 4 finished blind-phase runners:** `nf_run_validation`,
`nf_run_marc_validation_bundle`, `nf_run_brainstorm_iir_sos_check`, `nf_run_brainstorm_intro_validation`.
> **Do NOT archive** `nf_run_development_full_chain`, `nf_run_development_transition`,
> `nf_development_timeline_init/append`, `nf_development_maybe_inject_failure`,
> `nf_validate_development_feedback_audit` — these are the active Frozen **Step 0** harness
> (see Plan context above). `timeline_init/append` are additionally on the live path
> (`nf_run_live_resting/trial`). Archive this cluster only after Frozen Step 5.
> Note: `nf_run_development_full_chain` is the Step 0 end-to-end sim driver. If you still use it to
> exercise resting→transition→trial in simulation, **demote** it into `dev-archive/` but keep it
> runnable rather than deleting — revisit once the `ft_realtime_fileproxy` sim milestone has its own clean driver.

**`config/` — archive 4 dev configs:** `nf_brainstorm_intro_validation_config`,
`nf_development_session_config`, `nf_mock_live_test_config`, `nf_is_strict_step0_headless_contract`.

**`io/` — archive 3 validation IO:** `nf_export_brainstorm_ctf_to_validation_mat`,
`nf_save_validation_results`, `nf_load_validation_data`.

**`temp/` — archive/delete 1:** `inspect_brainstorm_intro_results.m` (scratch).

**`logs/codex/` — delete from working tree** (`build_code_summary.py`, `code_summary.txt`): generated artifacts.

Approx. archived code: ~9,000–9,500 lines of non-test `.m`, plus their tests (below).

---

## SPLIT (stays core, decompose under test guard)

| File | Lines | Split into (suggested) |
|---|---|---|
| `config/nf_check_config.m` | 1,499 | by concern: live-connection checks, spatial/matrix checks, baseline-compatibility checks, feedback/display checks, timing checks. One dispatcher + focused validators. **Highest priority — agents open this constantly.** |
| `main/nf_run_live_trial.m` | 826 | trial loop core / feedback wiring / cleanup+partial-save / preflight. |
| `main/nf_run_live_rt_dry_run.m` | 702 | preflight / loop / report assembly. |
| `main/nf_run_live_resting.m` | 556 | preflight / loop / baseline finalize+save. |
| `main/nf_run_live_chunk_smoke_test.m` | 548 | buffer probe / assertions / report. |
| `spatial/nf_prepare_live_combined_matrix.m` | 493 | precomputed loader / technical-fallback / revalidation. **Split proactively — this is where `compute_live` lands and it will grow.** |
| `main/nf_run_live_self_test.m` | 396 | scenario setup / execution / assertions. |
| `config/nf_live_config.m` | 361 | connection block / timing block / spatial block. |

`feedback/nf_feedback_init.m` (300) — borderline; split only if it keeps growing.

---

## Tests (210 files / 10,710 lines) — the safety net, not bloat

**Rule: a file and its tests move together.** Never archive code but keep its tests on the default path (they'll fail), and never keep code but archive its behavior tests.

- **KEEP** (refactor safety net — these pin the algorithm): tests matching `rt`, `buffer`, `baseline`,
  `feedback`, `measure`, `zscore`, `zsmooth`, `filter_continuity`, `sos_gain`, `source`, `spatial`,
  `live_*`, `config_*`, `circle_feedback`, `safety`, `step3d_*`.
- **ARCHIVE alongside their code**: tests matching `synthetic`, `band_detection`, `fft_comparison`,
  `theta_recovery`, `iir_sos_comparison`, `brainstorm_intro`, `brainstorm_vs_streaming`,
  `marc_*`, `validation_report`, `offline_reference`, `development_*` (except see step0 split below).
- After moving, **`tests/run_all_tests.m` must stay green** on the KEEP set. That green run is the definition of "cleanup done."

### `step0_*` tests — DEFERRED (keep all for now)

> **Superseded by the Plan-context correction above.** The `step0_*` tests exercise the active
> Frozen **Step 0** harness, so **keep all 23 as-is** for now. The keep/rewrite/archive split below is
> retained only as the plan for **after** Frozen Step 5 retires the skeleton — do not execute it during
> the current cleanup.

### Precise `step0_*` test split (all 23 audited — DEFERRED, execute only after Frozen Step 5)

**KEEP as-is (5)** — drive KEEP-CORE units directly, no dependency on the archived full-chain driver:

| Test | Asserts (core unit) |
|---|---|
| `test_step0_development_producer_wait_dat` | dev FieldTrip replay producer `nf_make_development_fieldtrip_buffer` (KEEP sim infra) |
| `test_step0_phase_runner_defaults_unchanged` | `nf_wait_for_manual_start` defaults |
| `test_step0_transition_positive_backlog` | `nf_run_development_transition` inclusive discard range |
| `test_step0_transition_timeout_boundary` | `nf_run_development_transition` strict timeout |
| `test_step0_transition_zero_backlog` | `nf_run_development_transition` known-zero vs unknown |

Test fixtures these depend on — **KEEP**: `tests/nf_test_step0_config.m`, `tests/NFStep0FakePsychtoolbox.m` (rename later, drop "step0").

**REWRITE-then-KEEP (8)** — assert a core invariant worth keeping, but currently ride on the archived
`nf_run_development_full_chain` driver / dev failure-injection. Retarget each onto the production runner
or core unit named, then keep. Fable/Opus work (assertion-preserving rewrite):

| Test | Core invariant to preserve | Retarget onto |
|---|---|---|
| `test_step0_development_label_enforcement` | dev/technical-fallback matrix cannot claim production | `nf_prepare_live_combined_matrix` + `nf_finalize_config` |
| `test_step0_fresh_trial_state` | filter/buffer/z-smooth reset fresh at trial start | `nf_run_development_transition` + production trial |
| `test_step0_logger_failure_cleanup` | logger cleans up on append/close failure | `io/` logger + `nf_run_live_resting` |
| `test_step0_source_readiness_advancement` | source must show deterministic advance | `source/` init/has_next/get_chunk |
| `test_step0_source_readiness_rejection` | reject non-advancing transport | `source/` readiness path |
| `test_step0_psychtoolbox_flip_audit` | signed PTB flip-timing audit | `feedback/` + a production trial |
| `test_step0_partial_report_trial_failure` | partial log preserves trial-failure identity | `nf_save_partial_log` + `nf_run_live_trial` |
| `test_step0_partial_report_resting_failure` | partial log preserves resting-failure identity | `nf_save_partial_log` + `nf_run_live_resting` |

**ARCHIVE (10)** — test the Step 0 harness / apparatus itself, not the shippable algorithm:

`test_step0_artifact_readback`, `test_step0_config_policies` (Step 0 policy centralization +
`nf_is_strict_step0_headless_contract`), `test_step0_development_full_chain_success`,
`test_step0_feedback_audit_bounds` (drives archived `nf_validate_development_feedback_audit`),
`test_step0_no_runtime_magic_values` (Step 0 closure audit — optionally repurpose as a config-centralization lint),
`test_step0_partial_report_feedback_failure`, `test_step0_partial_report_transition_failure`,
`test_step0_result_schema_stable` (full-chain result schema), `test_step0_room_representative_workload`
(**reconstruct later** as the `ft_realtime_fileproxy` sim-milestone integration test),
`test_step0_timeline_html_escaping`.

> The three KEEP transition tests and the two production live runners all call
> `nf_development_timeline_init/append` — which is exactly why those two files are KEEP-CORE (corrected above).

---

## Execution sequence (risk-ordered)

0. **Safety.** `git tag pre-cleanup-2026-07-18` on current `main`; create branch `cleanup`. All work on the branch. *(Haiku)*
1. **Gitignore run artifacts.** Add `outputs/` (dated session folders, `.mat`, `.csv`, figures) and `logs/codex/` to `.gitignore`; remove from tracking. Zero behavioral risk. *(Haiku)*
2. **Quarantine ARCHIVE-DEV.** Move the files above + their tests into `dev-archive/` preserving subpaths. Fix `nf_add_paths.m` so `dev-archive/` is *not* on the default path. Run test suite. *(Sonnet)*
3. **Split the big files.** Start with `nf_check_config.m`, then the `main/` live runners, then `nf_prepare_live_combined_matrix.m`. One file per PR, tests green after each. *(Fable/Opus for `nf_check_config` and `nf_prepare_live_combined_matrix`; Sonnet for the `main/` runners.)*
4. **Defer deep RT-core refactor** until `compute_live` (real Brainstorm CombinedMatrix) is implemented and the `ft_realtime_fileproxy` sim→live milestone passes. Refactoring load-bearing, still-incomplete scientific code before it's validated risks silent behavior loss.

## Model routing

| Work | Model | Why |
|---|---|---|
| `git`/gitignore, path renames, file moves | Haiku | Trivial, mechanical. |
| Archive relocation + test moves, `main/` runner splits | Sonnet | Mechanical but test-guarded; cheap. |
| Split `nf_check_config` & `nf_prepare_live_combined_matrix`; `compute_live` CombinedMatrix; inverse kernel / artifact projector / feedback implementations; any RT-core-adjacent change | Fable (or Opus) | High-judgment, numerically demanding, long-horizon; being wrong is expensive. |

## What this achieves

- Working set handed to agents drops ~35% (archived code + gitignored artifacts leave the default path).
- The single worst file for agent context (`nf_check_config.m`, 1,499 lines) is decomposed.
- The shippable core is cleanly separated from development apparatus — the exact partition Brainstorm packaging needs later.
- Nothing on the path to the goal is lost; the ~200-test suite guards every step, and archived history stays in git.
