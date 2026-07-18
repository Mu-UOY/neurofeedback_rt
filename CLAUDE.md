# CLAUDE.md — neurofeedback_rt

Context for AI coding agents (Claude Code / Codex) working in this repo. Read this first.

## What this project is

Real-time MEG neurofeedback. Participants learn to voluntarily increase **theta-band (4–8 Hz)
power in the left intraparietal sulcus (IPS)**. MEG is recorded continuously, converted online into
a baseline-normalized left-IPS theta estimate, and shown as an expanding circle projected into the
MEG room. The circle is a visual representation of the participant's own theta activity — not a
stimulation device.

Scientific lineage and full detail: `docs/HISTORY.md`, `docs/ARCHITECTURE.md`.

## Central architectural principle

**Different data producers before the FieldTrip buffer; one identical neurofeedback program after it.**

- **Simulation:** recorded CTF dataset → `ft_realtime_fileproxy` → local FieldTrip buffer → `neurofeedback_rt`
- **Live (MEG room):** CTF acquisition → `ctf2t` bridge → FieldTrip buffer (`10.68.1.239`) → the *same* `neurofeedback_rt`

Switching sim → live changes **source configuration only**, never the scientific processing algorithm.
Endpoints: `docs/FIELDTRIP_ENDPOINTS.md`.

## Default real-time parameters (all config-controlled)

- Sampling rate: 2400 Hz
- Input chunk: 0.2 s = 480 samples (transport/processing unit)
- Power window: 2.0 s = 4800 samples (measurement unit)
- Target band: 4–8 Hz theta
- Filtering method: **causal IIR/SOS** (decided — see below)

## Decisions already made (do not re-litigate)

- **Filtering: IIR/SOS, causal, stateful.** The blind-development phase compared FFT/offline
  approaches via synthetic simulations and chose IIR/SOS. The comparison apparatus is now legacy
  (being archived per the cleanup manifest).
- **Measure:** per valid 2 s window, compute theta power per IPS source row, then average rows into
  one scalar. Do not collapse source time series before power.
- **Baseline:** distribution of 2 s window powers → mean/std after outlier handling.
- **Trial feedback:** z-score vs saved baseline → clip → EMA smooth → monotonic map to circle radius
  (area-preserving).

## Repo shape

**Shippable core (the algorithm — protect, this is what ships to Brainstorm):**
`rt/ baseline/ buffer/ feedback/ measure/ sync/ safety/ spatial/ source/`, plus the production
runners in `main/` (`nf_run_resting`, `nf_run_trial`, `nf_run_live_*`, `nf_run_development_transition`),
`config/` (core), `io/` logging.

**Development apparatus (being archived to `dev-archive/`, never ships):**
`validation/` (filter-decision scaffolding), most of `analysis/`, dev harnesses in `main/`
(`nf_run_validation`, `nf_run_marc_validation_bundle`, `nf_run_brainstorm_*`,
`nf_run_development_full_chain`), dev configs, `temp/`.

Full file-by-file classification, split targets, sequencing, and model routing:
**`CLEANUP_MANIFEST.md`** (repo root). Follow it phase by phase.

## Open work (the actual goal)

1. **`compute_live` CombinedMatrix** — the real Brainstorm spatial operator
   (scout × inverse kernel × good-channel × artifact projector × reference/gain × channel mapping).
   Currently stubbed: `spatial/nf_prepare_live_combined_matrix.m` errors on `ComputeLive`; the live
   path runs on a `TechnicalPlaceholder` matrix.
2. **Close the sim → live milestone** — full pipeline correct against an `ft_realtime_fileproxy`
   replay of a recorded CTF dataset, then point the same program at the MEG-room buffer via config.

## Working rules for agents

- **Git first.** Before any edit, run `git status`. If on `main`/`master`, create and switch to a
  working branch (e.g. `cleanup` or a feature branch) and work only there. Tag a restore point
  before large refactors.
- **Tests are the safety net.** `tests/run_all_tests.m` (~200 tests). Keep them green — a green run
  on the kept set is the definition of "done" for the cleanup. Move code and its tests together.
- **When archiving/refactoring, preserve behavior.** Never silently drop a correction, a validation
  check, or a test assertion. If a test rides on a dev driver, retarget it onto the production
  runner rather than deleting its coverage.
- **Config-driven.** Nothing protocol/participant/machine/room-specific belongs inside processing
  functions — it goes through configuration. See `docs/ARCHITECTURE.md` → CONFIGURATION REQUIREMENT.
- **Prefer small files.** Large files confuse agents and burn tokens; the manifest lists split targets.

## Doc index

- `docs/ARCHITECTURE.md` — end-to-end plan, phases, processing chain, config schema.
- `docs/HISTORY.md` — scientific origin, Benjamin's prototype, what was inherited vs rebuilt.
- `docs/MEG_TOOLS_REFERENCE.md` — Brainstorm, FieldTrip, McGill CTF MEG unit.
- `docs/FIELDTRIP_ENDPOINTS.md` — sim and live source endpoints.
- `CLEANUP_MANIFEST.md` — keep / archive / split spec.
