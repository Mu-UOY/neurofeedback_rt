NEUROFEEDBACK RT — END-TO-END PLAN AND ARCHITECTURE

GOAL

Teach participants to voluntarily increase or regulate theta-band activity in the left intraparietal sulcus (IPS) using real-time MEG neurofeedback. MEG activity is recorded continuously, converted into an online estimate of left-IPS theta power, normalized against the participant’s own resting baseline, and displayed as the size of a circle projected inside the MEG room.

The participant’s task is to make the circle larger by changing their mental state. The circle is only a visual representation of the current baseline-normalized IPS theta activity; it is not an external brain-stimulation device.

PROGRAM GOAL

Develop a production-equivalent simulated real-time system before using the live MEG stream.

In simulation, a recorded CTF MEG dataset is replayed in real time with ft_realtime_fileproxy. The replay process publishes the dataset to a local FieldTrip buffer. The neurofeedback program connects to that buffer, receives samples in real-time chunks, applies the complete sensor-to-IPS processing chain, computes theta power and z-scores, and presents the expanding-circle feedback through Psychtoolbox.

In the MEG room, the downstream neurofeedback program must remain the same. The simulated FieldTrip source is replaced by the real FieldTrip server produced by the CTF-to-FieldTrip bridge. The source connection is selected through configuration, principally the FieldTrip host/IP and port. The live server is expected at 10.68.1.239. Room-specific channel metadata, display settings, triggers, and participant-specific matrix files must also be supplied through configuration, but the real-time processing algorithm must not change.

CENTRAL ARCHITECTURAL PRINCIPLE

Different data producers before the FieldTrip boundary; one identical neurofeedback program after the FieldTrip boundary.

Simulation:
Recorded CTF dataset
→ ft_realtime_fileproxy
→ local FieldTrip buffer
→ neurofeedback_rt
→ left-IPS theta-power estimate
→ Psychtoolbox circle feedback

Live:
CTF MEG acquisition
→ ctf2t
→ MEG-room FieldTrip buffer
→ the same neurofeedback_rt program
→ left-IPS theta-power estimate
→ Psychtoolbox circle feedback

MEG-ROOM SETUP

Two computers are involved:

1. Acquisition computer
2. Stimulation computer

Planned data path:

CTF MEG sensors
→ CTF acquisition system
→ CTF shared-memory ring buffer on the acquisition side
→ mirrored/copied CTF-compatible memory accessible to the stimulation side
→ ctf2t bridge
→ FieldTrip real-time buffer
→ MATLAB neurofeedback program on the stimulation computer
→ Psychtoolbox
→ projector connected to the stimulation computer

The acquisition computer controls and records the MEG data. CTF writes incoming sensor samples into its acquisition-side shared-memory structure. A CTF-specific mechanism makes a corresponding stream available to the stimulation computer. The ctf2t process reads that CTF stream and republishes it in FieldTrip-buffer format.

The FieldTrip buffer is the interface used by MATLAB. The neurofeedback program does not directly read CTF shared memory. It requests the FieldTrip header, waits for new samples, reads consecutive sample ranges, validates them, and passes accepted chunks into the real-time processing pipeline.

DEFAULT REAL-TIME PARAMETERS

All values are configuration-controlled. The current planned defaults are:

Sampling rate:
2400 Hz

Input chunk duration:
0.2 seconds

Samples per input chunk:
480 samples

Theta-power window duration:
2.0 seconds

Samples per power window:
4800 samples

Target frequency band:
4–8 Hz theta

The 0.2-second chunk is the transport and processing update unit. The 2-second window is the scientific measurement unit used to estimate theta power. Several consecutive chunks are accumulated in a rolling buffer to form each power window.

SPATIAL PROCESSING PACKAGE

Before nf_resting begins, the complete participant-specific spatial processing package must be prepared, validated, and saved.

The intended operator is:

CombinedMatrix =
ScoutSelector
× InverseKernel
× GoodChannelSelector
× ArtifactProjector
× ReferenceCorrection
× GainCorrection
× ChannelMapping

Equivalent notation:

CombinedMatrix =
S_IPS × K_inverse × E_good × P_artifact × R_CTF × D_gain × C_channels

The operator is applied to each incoming sensor chunk:

IPSData = CombinedMatrix × SensorChunk

The exact factors included depend on what corrections have already been applied by CTF, the FieldTrip producer, or Brainstorm. No correction may be silently omitted or applied twice.

CHANNEL MAPPING AND SELECTION

Channel mapping is determined before nf_resting from:

- the channel labels and order provided by the FieldTrip header;
- the Brainstorm channel file;
- the channels expected by the inverse solution;
- the approved good-channel list.

Its responsibilities are to:

- verify that all required channels are present;
- reject duplicate or unknown channel labels;
- remove channels that are not inputs to the source model, such as ECG, EOG, triggers, and auxiliary channels;
- reorder the remaining MEG channels into the exact order expected by the Brainstorm operators;
- apply the approved good-channel selection.

Brainstorm does not automatically perform this reordering during the real-time run. The live program must explicitly construct and validate the mapping.

GAIN AND REFERENCE/COMPENSATION CORRECTIONS

Gain correction converts the numerical units of the FieldTrip samples into the units expected by the Brainstorm inverse model, but only if that conversion has not already been applied upstream.

Reference correction represents the fixed CTF compensation/reference operation expected by the Brainstorm model. For CTF MEG, this may include the selected gradient-compensation order, such as third-order compensation.

These corrections are not re-estimated for every chunk or every 2-second window. Their settings are determined before resting, recorded in the processing package, and applied identically during artifact calibration validation, resting, and trial.

ARTIFACT PROJECTOR

The artifact projector is estimated before the resting baseline from a continuous artifact-calibration recording or from another approved recording containing enough representative artifact events.

Artifact data still arrive from FieldTrip in ordinary real-time chunks, but projector estimation is not based on the 2-second theta-power window. The continuous sensor recording is preserved or accumulated, artifact events are detected or marked, and artifact-specific segments are extracted.

Typical components include:

- eye blinks and eye movements;
- heartbeat activity;
- muscle or other structured noise, when appropriate.

For separately defined projectors:

ArtifactProjector =
P_muscle × P_heartbeat × P_blink

The preferred construction is a single projector based on a joint orthonormal artifact subspace:

U_all = orth([U_blink, U_heart, U_muscle])

ArtifactProjector =
I - U_all × U_all'

Each candidate component must be inspected and approved before inclusion. The projector is then fixed and applied consistently to both resting and trial data.

The artifact projector suppresses repeatable spatial artifact patterns. A separate real-time residual-artifact detector must still mark contaminated 2-second power windows as invalid so that large remaining artifacts do not enter the baseline or control the feedback.

INVERSE KERNEL

The inverse kernel is precomputed in Brainstorm from the participant’s anatomy, forward/head model, noise assumptions, source orientation settings, channel model, and inverse-method configuration.

It maps cleaned and correctly ordered MEG sensor data into source-space activity:

SourceData =
InverseKernel × CorrectedSensorData

The inverse kernel must be used with the same channel order, units, compensation state, good-channel set, and projector assumptions for which it was generated.

LEFT-IPS SCOUT SELECTION

The left-IPS scout is defined and approved in Brainstorm.

The scout operator selects the left-IPS source rows from the full inverse solution:

K_IPS =
ScoutSelector × InverseKernel

The intended real-time representation preserves the selected IPS source rows through spatial projection and temporal filtering. For each valid 2-second window:

1. theta power is computed separately for every selected IPS source row;
2. those source-row powers are averaged to obtain one scalar left-IPS theta-power value.

This avoids collapsing source time series before power calculation.

FILTER PREPARATION

The causal IIR/SOS theta-band filter is generated from configuration before resting begins.

Its design depends on:

- sampling rate;
- target frequency band;
- filter type;
- filter order;
- SOS implementation and numerical requirements.

The coefficients do not come from the artifact-calibration recording.

Filtering is causal and stateful. Each chunk is filtered using the state left by the preceding chunk. Filter state is preserved within a resting or trial phase and reset at controlled phase boundaries.

CORE REAL-TIME LOOP

For every incoming FieldTrip chunk:

1. Load the run configuration and prepared participant processing package.
2. Initialize the source adapter, real-time state, filter state, rolling buffer, logger, and display state.
3. Wait until the next requested FieldTrip samples are available.
4. Read one consecutive sensor-data chunk.
5. Validate sampling rate, dimensions, channel identity, sample indices, continuity, timing, gaps, and dropped or overwritten samples.
6. Apply CombinedMatrix to produce the left-IPS source rows.
7. Apply the causal stateful IIR/SOS theta-band filter.
8. Append the filtered source samples to the rolling circular buffer.
9. Determine whether a complete fresh 2-second power window is available.
10. Reject the window if it is incomplete, in filter warm-up, discontinuous, contains a dropped-sample gap, or fails residual-artifact criteria.
11. For a valid window, compute mean-squared theta amplitude for each IPS source row and average those powers into one scalar Measure.Power.
12. Package power, validity, sample indices, window bounds, acquisition timing, processing timing, gap flags, artifact flags, and provenance into one Measure record.
13. During resting, append valid Measure.Power values to the baseline accumulator.
14. During trial, normalize valid Measure.Power against the saved baseline.
15. Clip and smooth the trial z-score.
16. Convert the smoothed z-score into a normalized feedback value and circle radius.
17. Update the Psychtoolbox display at the configured feedback cadence.
18. Save the Measure and associated timing/quality metadata for reconstruction, plotting, auditing, and validation.

POWER AND BASELINE CALCULATION

The resting baseline must use the same measurement definition as the trial.

Both phases use:

- the same FieldTrip channel interpretation;
- the same CombinedMatrix;
- the same theta filter;
- the same 2-second power-window duration;
- the same IPS row-wise power calculation;
- the same validity and residual-artifact rules.

During resting, each accepted 2-second window produces one scalar power value:

P1, P2, ..., PN

After quality control and configured outlier handling:

BaselineMean = mean(valid resting powers)

BaselineStd = standard deviation(valid resting powers)

The baseline is therefore a distribution of 2-second left-IPS theta-power measurements, not a distribution of individual MEG samples and not a distribution of 0.2-second chunks.

The power window may update every 0.2 seconds, producing strongly overlapping windows. The window duration and the stride at which resting values are retained must be independently configurable. Trial feedback may use every valid update, while resting may optionally retain values at a larger stride to reduce nearly duplicate baseline observations.

TRIAL NORMALIZATION AND FEEDBACK

For each valid trial power value:

ZRaw =
(CurrentPower - BaselineMean) / BaselineStd

Then:

ZClipped =
ZRaw limited to configured lower and upper bounds

ZSmoothed(t) =
alpha × ZSmoothed(t-1)
+ (1 - alpha) × ZClipped(t)

The smoothed z-score is mapped into a configured normalized interval and then into the circle’s target radius. The display mapping must be monotonic: greater left-IPS theta power relative to baseline produces a larger circle.

The circle may use an area-preserving radius mapping so that the displayed area, rather than radius alone, changes proportionally with feedback value.

END-TO-END RECORDING PHASES

PHASE 1 — ARTIFACT CALIBRATION AND SCIENTIFIC PREPARATION

Purpose:
Build and validate the participant-specific spatial processing package.

Flow:

Continuous artifact-calibration MEG
→ receive/store ordinary FieldTrip chunks
→ detect and mark artifact events
→ extract artifact-specific epochs or segments
→ estimate and inspect artifact components
→ construct ArtifactProjector
→ load channel mapping and correction operators
→ load Brainstorm good-channel selection
→ load inverse kernel and left-IPS scout
→ compose CombinedMatrix
→ generate IIR/SOS coefficients from configuration
→ validate dimensions, units, channel order, matrix identity, and scientific consistency
→ save the complete preparation package

No 2-second theta-power window is imposed for projector estimation. Artifact-specific event windows or continuous segments are used according to the artifact type.

PHASE 2 — NF_RESTING

Purpose:
Create the participant-specific baseline distribution used for trial z-scores.

Flow:

Continuous FieldTrip stream
→ receive 0.2-second chunks
→ validate samples and channels
→ apply CombinedMatrix
→ apply causal theta filter
→ fill rolling buffer
→ evaluate complete 2-second windows
→ reject invalid, warm-up, discontinuous, or artifact-contaminated windows
→ compute scalar left-IPS theta power
→ accumulate valid power values
→ apply configured quality and outlier rules
→ calculate BaselineMean and BaselineStd
→ save baseline with complete configuration and processing-package identity

PHASE 3 — TRANSITION

Purpose:
Move cleanly from resting to trial without treating operator-delay data as trial data.

Flow:

Resting ends
→ FieldTrip producer continues running
→ operator prepares the participant and starts the trial
→ samples accumulated during the delay are identified and discarded
→ source cursor moves to the current live edge
→ filter state, rolling buffer, power-window state, z-score smoother, and feedback state are reset
→ trial begins with fresh samples
→ feedback remains unavailable until a complete valid 2-second trial window exists

PHASE 4 — NF_TRIAL

Purpose:
Run the actual neurofeedback task.

Flow:

Continuous FieldTrip stream
→ receive and validate 0.2-second chunks
→ apply the same CombinedMatrix
→ apply the same causal theta filter
→ build the same 2-second power windows
→ reject invalid or contaminated windows
→ compute left-IPS theta power
→ calculate ZRaw from the saved baseline
→ clip and smooth the z-score
→ map ZSmoothed to feedback value and circle radius
→ update Psychtoolbox
→ log all neural, quality, timing, and display values

DATA STORAGE

Every run creates a unique session folder. At minimum, it stores:

- finalized run configuration;
- source/FieldTrip header and channel metadata;
- CombinedMatrix and provenance or a cryptographic identity of the approved matrix package;
- artifact-calibration summary and approved component identities;
- saved resting baseline;
- per-window Measure records;
- chunk continuity and timing metadata;
- z-scores, feedback values, and circle-display timing;
- session and phase summaries;
- stop reason and error information;
- partial outputs if a run terminates early;
- validation tables, plots, and reports.

Each Measure must contain enough information to reconstruct what neural window produced each power value and each feedback update.

CONFIGURATION REQUIREMENT

Nothing protocol-specific, participant-specific, machine-specific, or room-specific may be hidden inside processing functions.

The configuration must define or reference:

- FieldTrip source mode, host, port, and timeouts;
- dataset path for simulation;
- sampling rate and chunk duration;
- target band and filter design;
- power-window duration and update stride;
- baseline-retention stride and quality thresholds;
- channel labels, mapping rules, and expected channel count;
- gain and CTF reference/compensation settings;
- artifact-projector file and residual-artifact thresholds;
- inverse-kernel, good-channel, and IPS-scout files;
- CombinedMatrix file and validation identity;
- z-score clipping and smoothing parameters;
- feedback mapping and Psychtoolbox display settings;
- trigger settings;
- phase durations and stopping rules;
- logging and output paths.

The simulated and live systems must use the same downstream configuration schema. Switching from simulation to live operation must change the source configuration and required room/session metadata, not the scientific processing algorithm.

