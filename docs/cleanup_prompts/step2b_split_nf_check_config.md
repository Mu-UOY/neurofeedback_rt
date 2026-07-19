# Step 2b prompt for Claude Code (Opus) — Split nf_check_config.m

> Run AFTER the cleanup checkpoint (HEAD at tag `post-code-summary-2026-07-18`, SHA `2f6c298`), from a
> clean tree green at 181. **Use Opus with extended thinking** (reserve Fable for `compute_live`).
> Behavior-preserving decomposition of a 1,499-line validator across MATLAB's file-private scoping.
> Scope is ONE file: config/nf_check_config.m. Paste the fenced block.
>
> SCOPING FACTS (relied on below): config/private/ functions are callable by functions in config/ (the
> parent) ONLY; two files inside config/private/ canNOT call each other; config/private/ is not on the
> path. Pre-scan found NO dynamic dispatch in the file; the 20 `.(...)` are dynamic FIELD accesses (data).

```text
Step 2b: Split config/nf_check_config.m (1,499 lines) into focused files, preserving behavior exactly.

PURPOSE
Decompose the largest, most-read config validator into smaller cohesive files with ZERO change to the
observable behavior of nf_check_config. The 181-test suite plus static/body/resolution checks gate each step.

MODEL/EFFORT: Opus, think hard at each design and verification step.

APPROVED DESIGN BOUNDARY (fixed — Design 1; do not invent alternatives):
  config/nf_check_config.m            (orchestrator + inline base checks; keeps main-only helpers local)
  config/nf_check_live_config.m       (live scaffold + live-only *_fields helpers as its LOCAL subfunctions)
  config/nf_fill_config_defaults.m    (defaults + defaults-only helpers as its LOCAL subfunctions)
  config/private/<one file per CROSS-CUTTING helper>  (helpers called by 2+ of the three units above)
- All three units live in config/ (parent), so each can legally call config/private/ helpers. Shared
  helpers are SINGLE-SOURCED in config/private/ (no duplication).
- ACCEPTED STRUCTURAL EXCEPTION: nf_check_live_config and nf_fill_config_defaults become path-visible
  implementation functions. This expands the repository's callable surface. It is explicitly accepted;
  it is NOT a claim that the callable surface is unchanged. No existing caller changes, and the observable
  behavior of nf_check_config remains identical. nf_check_config must remain the ONLY repository caller of
  those two functions. Do not modify any production or test file to call them directly.
- Keep single-unit helpers local to their unit. A helper becomes a standalone config/private/ file only if
  called by 2+ units.

DEFINITION — "preserve behavior exactly" (observable behavior of nf_check_config that MUST NOT change):
- output value, class, shape, and the exact set/order of inserted/defaulted fields;
- validation ORDER and short-circuit/first-failure: a config that failed at check X before must still fail
  at check X with the same error IDENTIFIER and message after;
- all error identifiers AND messages; all warning identifiers, messages, and emission order;
- handling of empty / missing / NaN / string / char-vector / logical / numeric-flag inputs;
- any function-handle or string dispatch (pre-scan found none — confirm via the inventory-driven scan).
PERMITTED: changes to internal MException stack-frame file/function names caused solely by extraction.

PRECONDITIONS (verify; STOP if any fails)
- git branch --show-current == feature/step3d-live-feedback-self-test
- git merge-base --is-ancestor post-code-summary-2026-07-18 HEAD  (exit 0). Ideally HEAD == 2f6c298.
- git status --short --branch --untracked-files=all shows ONLY the branch header.
- Suite green: matlab -batch "cd tests; run_all_tests()" -> "All 181 tests passed."
  181 is intentional = original 205 minus the 24 blind-phase tests archived in Step 2a. Any other count is
  a precondition FAILURE even if all executed tests pass — STOP.
- Record and report BASE_SHA = current HEAD.
- BASELINE SOURCE: every function-inventory and body comparison in this task MUST read the baseline from
    git show BASE_SHA:config/nf_check_config.m
  never from the progressively edited worktree or an intermediate commit. Store any scratch inventory/
  normalized-body records OUTSIDE the repo (system temp dir); they must never appear in git status.

PHASE 0 — call-graph + scoping + hazard analysis (READ-ONLY; make no changes)
1. Internal call graph from the baseline: for every subfunction, which callers use it (main / live block /
   defaults block / other subfns). Classify: main-only, live-only, defaults-only, or CROSS-CUTTING (2+ of
   the three prospective units).
2. Inventory-driven hazard scan: for EVERY function in the baseline inventory, search the file for
   - direct calls; @<exact-name> handles; the exact name inside char vectors / string scalars;
     str2func / func2str / feval references to that name; anonymous handles that capture/invoke a local.
   Also report nested functions vs ordinary local subfunctions, and any persistent/global/onCleanup/eval/
   evalin/assignin/mfilename/dbstack/inputname usage. If any moving function's semantics depend on one of
   these, STOP.
3. PRIVATE-SCOPE FEASIBILITY (Design 1): list every required cross-file call edge (caller file -> callee
   file) and prove each is legal: config/ -> config/private/ is legal; config/private/ -> config/private/
   is ILLEGAL. If any required edge is illegal, STOP and report it (do NOT work around it by adding
   config/private/ to the path, cd, duplication, handle tables, or eval/feval).
4. Name-collision checks in a FRESH matlab -batch that starts in the repo root and initializes the SAME
   path/bootstrap the test suite uses; confirm config/ is on the path and config/private/ is NOT explicitly
   added (do not call addpath on config/private/). For every prospective new name run:
     which('<name>', '-all')            and     which('private/<name>', '-all')
   Report all results; an empty ordinary which result is NOT proof of no private collision.
Report 1-4. Then STOP. Do NOT begin Phase 1 until I explicitly approve.

PHASE 1 — extraction plan for approval
Propose: each new file and its contents; for EVERY current subfunction its destination (stay-local in which
unit / standalone config/private/ file), with a one-line note on how each call site resolves under scoping.
Provide:
  RENAME MAP:  original name -> approved final name -> approved final file -> local|standalone
  CALL-SITE RENAME MAP: for every renamed function, every approved caller and the EXACT textual
    substitution:  caller file/function:  old callee expression -> new callee expression
Movement mechanics: the executable body — statement order, conditions, values, identifiers, messages, and
COMMENTS — stays byte-for-byte equivalent to the baseline except for (a) the approved declaration rename,
(b) uniform leading indentation forced by extraction, (c) the approved call-site substitutions above.
STRICT: do NOT add any new documentation, file header, help text, %#ok directive, comment, or formatting.
Only comments already attached to migrated code move into the new files.
Commit sequence: one approved BATCH = one commit; recommended: cross-cutting helpers -> defaults -> live.
Edit nothing yet. Then STOP. Do NOT edit any file until I approve. My Phase 1 approval authorizes the ENTIRE
sequence; execute all approved commits without further approval, but STOP on any failure.

PHASE 2..N — execute the approved sequence, one commit per batch
For each batch:
  1. Create/populate new file(s); move exact bodies; replace moved subfns with the approved calls; DELETE
     migrated local copies (no shadowing).
  2. STATIC checks (before tests):
     - git diff --check (no whitespace errors).
     - FUNCTION CONSERVATION (vs baseline from git show BASE_SHA:...): every baseline function is accounted
       for EXACTLY ONCE under its original or approved-renamed name — still local in nf_check_config, local
       in one extracted unit, or one standalone private file. None lost, merged, split, or duplicated.
       (Unrelated same-named locals elsewhere in the repo are out of scope.) Report before/after inventory.
     - BODY CONSERVATION: compare EVERY affected baseline function — not only moved functions — against its
       final implementation. This INCLUDES nf_check_config itself (which stays in place but whose call sites
       change) and any stay-local helper whose call sites change. Diff each final body against its baseline
       span after applying ONLY (a) the approved declaration rename where applicable, (b) the exact approved
       call-site substitutions, (c) uniform leading indentation from extraction. ANY other textual
       difference — comment changes, whitespace other than uniform extraction indentation, or unrelated
       lines in nf_check_config — is a failure even if tests pass. Report the comparison for every affected
       function.
     - CALLER CONTAINMENT: search the whole repo for ALL textual occurrences of nf_check_live_config and
       nf_fill_config_defaults; classify each as declaration, actual call, comment/string, or other.
       nf_check_config.m must be the only actual caller; any unexplained occurrence must be reported and
       is a failure.
     - RESOLUTION: in a fresh matlab -batch with the suite's path bootstrap, for each cross-file call run
       which('<callee>','in','<caller>'); canonicalize the returned path and require EXACT equality with the
       approved destination path (empty or any other path is a failure). For each new private file also run
       which('private/<name>','-all') and confirm the intended path is present.
  3. Suite: matlab -batch "cd tests; run_all_tests()" -> require "All 181 tests passed." exactly.
  4. On ANY failure (static/body/containment/resolution/test): do NOT commit, do NOT continue, do NOT
     broaden the change. Preserve the failing worktree; report the first failing check/test with its error
     identifier + message and the current diff; STOP.
  5. On success: git diff --name-status (only intended config/ paths; nothing under outputs/ or logs/),
     commit with a precise message, report HEAD.

PHASE FINAL — verification + report
- git diff --name-status BASE_SHA..HEAD : EVERY changed path must begin with config/. Report the list.
- git status --short --branch --untracked-files=all : clean (no scratch files leaked).
- Report BASE_SHA, final HEAD, commit list, new line counts of nf_check_config.m and each new file, the
  rename map, function+body conservation confirmations, caller-containment confirmation, and
  "All 181 tests passed." after the last commit.
- If nf_check_live_config.m remains ~900 lines, recommend a later Step 2b-2 sub-split by concern but do
  NOT do it here.
```
