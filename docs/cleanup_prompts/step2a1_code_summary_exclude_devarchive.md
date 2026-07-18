# Step 2a.1 prompt for Claude Code (Sonnet) — Exclude dev-archive/ from the code summary

> Run AFTER Step 2a is committed and the suite is green at 181. Paste the fenced block into Claude Code
> on branch `feature/step3d-live-feedback-self-test`.
>
> The code-summary generator (`logs/codex/build_code_summary.py`) and the hygiene test
> (`tests/test_logs_codex_hygiene.m`) are COUPLED: the test asserts the generator contains an exact
> string literal of the excluded-directory set. Both must change byte-for-byte together, or the test
> fails. This prompt makes the generator skip `dev-archive/`, updates the test to match, regenerates the
> (gitignored) summary, and commits only the tracked change(s).

```text
Step 2a.1: Teach the code-summary generator and its hygiene test to exclude dev-archive/.

PURPOSE
After Step 2a, dev-archive/ holds finished apparatus but the code summary still lists it (it counted 345
files including the 50 moved). Make logs/codex/build_code_summary.py skip dev-archive/ so agents stop
re-reading archived code, and keep tests/test_logs_codex_hygiene.m in exact agreement.

PRECONDITIONS (verify; STOP if any fails)
- git branch --show-current == feature/step3d-live-feedback-self-test
- Step 2a is committed; git status is clean.
- Baseline green: matlab -batch "cd tests; run_all_tests()" -> "All 181 tests passed."

PHASE 0 — read-only preflight
1. Determine tracking status: run  git ls-files logs/codex/  and report whether build_code_summary.py
   and code_summary.txt are tracked. (Expected: code_summary.txt is gitignored/untracked; build_
   code_summary.py may be force-added/tracked or untracked — record which.)
2. Confirm the generator currently has the line EXACTLY:
       EXCLUDED_TOP_LEVEL_DIRECTORIES = {".git", "logs", "outputs"}
   and that tests/test_logs_codex_hygiene.m asserts that same exact literal via contains(...).
3. Confirm the current code_summary.txt DOES contain "FILE: dev-archive/" entries (proving the problem).
Report findings. Make no changes.
[CONFIRM]

PHASE A — edit the generator (local file)
In logs/codex/build_code_summary.py change the set to add "dev-archive", alphabetically, to EXACTLY:
       EXCLUDED_TOP_LEVEL_DIRECTORIES = {".git", "dev-archive", "logs", "outputs"}
Change nothing else. (parts[0] == "dev-archive" will now be skipped by the existing rglob filter.)
[CONFIRM]

PHASE B — edit the hygiene test to match, byte-for-byte
In tests/test_logs_codex_hygiene.m:
  1. Update the generator-literal assertion to the SAME new string:
       assert(contains(generatorText, ...
           'EXCLUDED_TOP_LEVEL_DIRECTORIES = {".git", "dev-archive", "logs", "outputs"}'));
  2. Add, alongside the existing .git/ logs/ outputs/ header checks:
       assert(~any(startsWith(headers, 'dev-archive/')));
Change nothing else. The single-quoted MATLAB string must match the Python literal exactly (same order,
spacing, and quotes).
[CONFIRM]

PHASE C — regenerate the (gitignored) summary
Run  py -3 logs/codex/build_code_summary.py  (no flags). Expect "Wrote ... from 295 MATLAB files"
(345 - 50 moved). Confirm the new code_summary.txt has NO "FILE: dev-archive/" entries.
[CONFIRM]

PHASE D — verify green
Run  matlab -batch "cd tests; run_all_tests()" -> expect "All 181 tests passed." The hygiene test now
runs the generator's --check against the regenerated summary and must PASS. If not exactly 181 or any
failure, STOP and report. Capture git status --porcelain=v1 before/after; report any non-ignored change.

PHASE E — commit only the tracked change(s)
Stage exactly:
  - tests/test_logs_codex_hygiene.m   (always tracked)
  - logs/codex/build_code_summary.py  ONLY IF Phase 0 found it tracked
Do NOT stage logs/codex/code_summary.txt (regenerated artifact). If Phase 0 unexpectedly found
code_summary.txt tracked, STOP and ask before staging it.
Show git diff --cached --name-status and git diff --cached --check. Commit as:
  `Exclude dev-archive/ from code-summary generator and hygiene check`
Report HEAD, git status (clean), and the 181 green result.

PHASE F — report
State whether build_code_summary.py was tracked (and thus in the commit) or local-only, the new file
count (295), and confirm the hygiene test passes against the regenerated summary.
```
