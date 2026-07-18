# Step 1 prompt for Claude Code (Sonnet) — Stabilize git state before any cleanup

> Paste everything in the fenced block below into Claude Code, running in the repo root on branch
> `feature/step3d-live-feedback-self-test`. It performs git hygiene only — no archiving, splitting, or
> renaming. Approval gates (`[CONFIRM]`) require you to reply in a later turn before it proceeds.
>
> **Ordering note (why WIP is committed before line-ending normalization):** `git add --renormalize .`
> on a dirty tree stages the *full current content* of tracked files, which would fold the milestone
> WIP into the normalization commit. Rather than stash/unstash across an EOL change (conflict-prone),
> this prompt commits the WIP first, then renormalizes on a clean tree — the git-documented approach.

```text
Step 1: Stabilize the git working tree before any cleanup.

PURPOSE
Read CLAUDE.md, CLEANUP_MANIFEST.md, and these two plans in docs/:
  1. "Next plan 3.0.txt"                                        — Step 3D live self-test plan.
  2. "Neurofeedback_Frozen_Full_FieldTrip_Simulation_Plan_v1.0.txt" — full simulation plan, at Step 0.

The uncommitted work in this tree is REAL milestone work, not cleanup debris. It is primarily:
  A. Step 3D live self-test implementation (nf_run_live_self_test, nf_run_live_trial/resting, live
     source/config, their tests).
  B. Frozen Step 0 full-chain skeleton (nf_run_development_full_chain, nf_run_development_transition,
     nf_development_timeline_*, nf_development_maybe_inject_failure,
     nf_validate_development_feedback_audit, step0_* tests).

Your job in this step is ONLY to: inspect and preserve the WIP; commit it in groups I approve; then
create one isolated line-ending normalization commit; then run the test suite and report whether the
committed baseline is green.

Do NOT archive, move, delete, rename, split, rewrite, or otherwise clean up any .m file.
Do NOT edit source or tests to fix a failure. A clean but failing tree is NOT "green".

CONFIRMATION GATES
At every [CONFIRM], stop your response completely. Do not run anything after that marker until I reply
in a later turn. The marker is a hard stop, not a request for acknowledgement.

HARD CONSTRAINTS
- Never `git push`. Never create or switch branches. Never amend/rebase/reset --hard/clean/force-delete.
- Never manually modify, stage, delete, clean, or commit anything under outputs/ or logs/. Test runs may
  write ignored files there; that is fine, but never stage or commit them.
- Never discard tracked or untracked WIP.
- Never commit generated, temporary, binary, cache, autosave, editor-metadata, output, or log files
  unless I explicitly approve them.
- One logical change per commit. Stage WIP by explicit file path only — never `git add .`/`-A` for a
  WIP commit (that would sweep in the pending line-ending changes).
- Do not split one file across commits via partial-hunk staging unless I explicitly approve that file.
- Stop and ask whenever a command, a file's workstream, or a result is ambiguous.

PHASE A — branch & lock verification (read-only)
1. Run: git branch --show-current
        git status --short --branch --untracked-files=all
2. Expected branch: feature/step3d-live-feedback-self-test. If it differs, STOP and report; do not switch.
3. If git reports a .git/index.lock: determine whether a live git process may own it. Remove it ONLY if
   clearly stale. If ownership is uncertain, STOP.
4. Make no changes in this phase.

PHASE B — read-only WIP snapshot
Report:
- Current branch and HEAD.
- git status --short --branch --untracked-files=all
- git diff --shortstat
- git diff --ignore-cr-at-eol --shortstat      (EOL-specific; NOT -w)
- git diff --cached --shortstat
- git ls-files --eol   (summarize the LF/CRLF mix)
- All untracked files grouped by top-level folder.
Expectation only (re-measure; do not assume): on Windows git this tree shows roughly ~34 substantively
modified tracked files plus ~94 untracked files, and little or no line-ending noise. (A Linux/sandbox git
without core.autocrlf may instead report ~199 "modified" purely from CRLF differences — that is a tooling
artifact, not real change.) Report the ACTUAL current counts. Confirm the EOL situation with
--ignore-cr-at-eol and git ls-files --eol rather than assuming.
Create a durable read-only recovery record OUTSIDE outputs/ and logs/ capturing: the tracked diff, the
staged diff (if any), and the full untracked-file inventory. Do not modify or remove any WIP.
[CONFIRM]

PHASE C — classify the substantive WIP
Review tracked changes with `git diff --ignore-cr-at-eol` (so CRLF noise doesn't obscure real changes).
For each tracked modified file report: path, brief substantive change, proposed workstream, and whether
it spans multiple workstreams.
For each untracked file report: path, type, approx size, apparent purpose, and whether it looks authored
vs generated/temporary/binary/autosave/test-output, plus proposed workstream and whether to exclude it.
Group into:
  A. Step 3D live self-test
  B. Frozen Step 0 skeleton
  C. Shared/integration files legitimately needed by both
  D. Unclassified or suspicious (generated/temporary/artifact) — propose to EXCLUDE
Propose exact commit groupings, file lists, order, and messages. Stage nothing yet. I decide the final
grouping and messages.
[CONFIRM]

PHASE D — commit the approved WIP groups
For each approved group, in order:
1. Stage ONLY that group's approved files, by explicit path.
2. Show: git diff --cached --name-status  and  git diff --cached --stat  and a short substantive summary.
3. Verify nothing from outputs/, logs/, another group, or the excluded set is staged, and that no
   line-ending-only files were swept in (compare staged set to the approved list exactly).
4. Commit with the approved message. Report HEAD and git status after each commit.
Do not use partial-hunk staging unless I approved it for the named file.

PHASE E — establish whether the WIP baseline is green (pre-normalization)
1. Confirm tests/run_all_tests.m exists; determine how it is launched; confirm MATLAB is available and
   report its version. Do not substitute Octave unless the repo documents it and I approve.
2. Note whether the suite writes into outputs/ or logs/ (ignored writes are acceptable; never stage them).
3. Run the documented command. Report: exact command, exit status, passed/failed/skipped/errored counts,
   names + brief diagnostics of any failures, runtime, and whether the run modified the tree.
Do not fix failures. If red, report "clean but not green" and STOP for approval before Phase F.
[CONFIRM]

PHASE F — one isolated line-ending normalization commit (clean tree only)
Precondition: the only remaining working-tree changes are line-ending differences (the WIP is committed).
Verify this first: `git status` should show no un-committed substantive changes; `git diff --ignore-cr-at-eol
--shortstat` should be ~empty while `git diff --shortstat` still shows the EOL churn. If substantive
changes remain, STOP.
1. Add .gitattributes at repo root with exactly:
       * text=auto
       *.m text
       *.md text
       *.txt text
   (No `eol=lf`: normalize to LF in the repo but leave working-tree endings to core.autocrlf,
   avoiding a forced Windows working-tree conversion and re-checkout.)
2. From the repo root run: git add --renormalize .   (single dot). Ensure outputs/ and logs/ are not staged.
3. Verify the staged set is line-ending-only: `git diff --cached --ignore-cr-at-eol --shortstat` should be
   ~empty (no substantive content), and the staged file list should contain no outputs/, logs/, or binary
   files. Show git diff --cached --stat.
[CONFIRM]
4. Commit alone as: Normalize line endings (add .gitattributes)

PHASE G — verify green after normalization
Re-run the test suite exactly as in Phase E. Report the same fields. Confirm results match the pre-
normalization run (normalization must not change behavior). Do not fix failures.

PHASE H — final report
Report: branch; HEAD and the list of commits created this step; git status --short --branch
--untracked-files=all; whether the tree is clean; MATLAB version; test command and result; any excluded/
suspicious files; and whether the baseline is genuinely green.
Do NOT create a cleanup branch or begin any archive/split/rename/manifest work — that is the next prompt.
```
