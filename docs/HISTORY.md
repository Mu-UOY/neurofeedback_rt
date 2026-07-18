NEUROFEEDBACK RT — BRIEF HISTORICAL CONTEXT

SCIENTIFIC ORIGIN

This project follows a sequence of studies from Dr. Sylvain Baillet’s group on theta-band activity in the dorsal frontoparietal network, particularly the left intraparietal sulcus (IPS), during auditory working-memory manipulation.

In 2017, Philippe Albouy, Aurélien Weiss, Sylvain Baillet, and Robert Zatorre used MEG/EEG to identify theta activity in the dorsal auditory stream that predicted working-memory manipulation performance. They then applied theta-rhythmic TMS over the participant-specific left IPS target. Rhythmic stimulation entrained theta activity and improved behavioral performance, providing causal evidence that left-IPS theta oscillations contribute to auditory working-memory manipulation.

In 2022, Philippe Albouy, Zaida Martinez-Moreno, Roxane Hoyer, Robert Zatorre, and Sylvain Baillet showed that 5-Hz rotating visual stimulation could entrain the dorsal frontoparietal pathway and improve auditory working-memory performance. This extended the earlier TMS result by showing that IPS-related theta activity could also be influenced through rhythmic sensory stimulation.

The present project is the next methodological step. Instead of externally imposing theta activity through TMS or rhythmic visual stimulation, participants receive real-time information about their own left-IPS theta activity and attempt to increase it voluntarily. Their baseline-normalized theta activity is represented by visual circle feedback projected inside the MEG room.

BENJAMIN’S PROTOTYPE

Files he implemented:
BENbst_realtime.m
BENpanel_realtime.m
chunk_size.m
nf_blinking.m
nf_resting.m
nf_task.m
nf_trial.m

Before the current development phase, Benjamin Levesque Kinder built a Brainstorm-integrated MATLAB prototype for real-time MEG neurofeedback.

His work established much of the original practical concept:

FieldTrip buffer
→ CTF channel and acquisition metadata
→ Brainstorm head/source modelling
→ left-IPS theta estimate
→ resting baseline
→ trial z-score
→ Psychtoolbox feedback

Benjamin created a Brainstorm real-time control panel that allowed the operator to select the participant, FieldTrip host and port, processing-block duration, head-movement threshold, and experimental phase. The panel could launch blinking calibration, resting, neurofeedback trial, auditory task, and other real-time functions.

The prototype connected directly to a FieldTrip buffer and extracted the embedded CTF RES4 information. It used this information to reconstruct the Brainstorm channel file, identify MEG and reference channels, obtain channel gains and CTF reference coefficients, estimate the acquisition block size, and read consecutive blocks of samples from the buffer.

Benjamin also implemented participant head localization. Head-coil measurements were read from the FieldTrip stream and combined with digitized head points. The resulting sensor geometry was used in Brainstorm to compute an overlapping-spheres MEG head model and a weighted minimum-norm imaging kernel. A noise covariance stored in the Brainstorm database was copied into the real-time study before inverse computation. The selected left-IPS scout vertices were then used to reduce the source estimate to the target region.

ARTIFACT CALIBRATION

Benjamin implemented a dedicated blinking phase. Participants were instructed to blink naturally for approximately 20 to 30 seconds while continuous MEG data were collected.

The prototype:

- read the blinking data continuously from FieldTrip;
- applied channel gains and CTF third-order gradient correction;
- saved the accumulated recording into Brainstorm;
- ran Brainstorm SSP/PCA processing;
- opened Brainstorm’s manual SSP-selection interface;
- copied the selected active projector components into the participant’s real-time channel file.

This established the intended idea that participant-specific artifact components should be collected and approved before neurofeedback. However, the actual application of the selected SSP projector during the resting and trial loops was still commented out in the inherited code, so the complete artifact-correction path had not yet been closed.

RESTING BASELINE

Benjamin implemented a resting-state phase with Psychtoolbox instructions, fixation display, acquisition markers, and continuous FieldTrip reading.

For each processing block, the code:

- applied gains and CTF reference correction;
- transformed sensor-frequency data through the Brainstorm imaging kernel;
- selected the left-IPS scout;
- estimated theta activity, originally using a 4–6 Hz FFT range;
- also estimated an 8–12 Hz alpha control value;
- stored one theta and alpha value per block.

At the end of resting, the code removed values above and below configured percentiles and saved the remaining theta distribution’s mean, standard deviation, and upper-percentile threshold. These values became the reference for later trial z-scores.

NEUROFEEDBACK TRIAL

Benjamin implemented a real-time neurofeedback trial lasting approximately 120 seconds.

For each incoming block, the prototype:

- applied gains and CTF reference correction;
- estimated left-IPS theta and alpha activity;
- calculated a theta z-score from the saved resting mean and standard deviation;
- smoothed the z-score using the latest three block values;
- scaled the result into a feedback intensity between 0 and 1;
- displayed visual feedback through Psychtoolbox;
- sent parallel-port markers to the acquisition system;
- saved theta, alpha, z-score, smoothed z-score, and feedback values.

The trial code also contained an adaptive threshold system. Depending on performance in the preceding trial or session, the target threshold could increase by 10 percent. The feedback implementation used a fixed-size circle whose color changed with feedback intensity, although the current project direction uses circle size as the primary feedback variable.

AUDITORY TASK

Benjamin also implemented the associated auditory working-memory task in Psychtoolbox. The program presented forward and reversed melody conditions, normal and altered trials, collected participant responses, calculated accuracy, counterbalanced task order, and sent detailed acquisition triggers.

WHERE BENJAMIN REACHED

Benjamin’s work demonstrated that the major pieces could be connected in one MATLAB/Brainstorm environment:

- FieldTrip real-time access;
- CTF channel metadata and correction information;
- head localization;
- Brainstorm head-model and inverse-kernel computation;
- participant-specific IPS selection;
- blinking calibration and SSP selection;
- resting baseline estimation;
- trial z-scoring;
- Psychtoolbox feedback;
- acquisition triggers;
- auditory task control.

It was therefore a valuable proof-of-concept and the direct technical starting point for the current project.

However, the inherited code had not yet become a production-equivalent or fully validated neurofeedback system. The main limitations were:

- strong dependence on the live Brainstorm and MEG-room environment;
- hardcoded file paths, screen numbers, participant information, scout files, frequencies, timings, and trigger addresses;
- large monolithic functions with duplicated processing logic;
- unresolved TODOs around channel gains, compensation, projectors, smoothing, and head tracking;
- SSP projectors selected in Brainstorm but not consistently applied in resting and trial;
- blockwise FFT calculations rather than the current causal stateful filter and rolling 2-second power estimator;
- unclear scientific definition of the final IPS power measure;
- no validated precomputed CombinedMatrix reproducing the full sensor-to-IPS chain;
- no production-equivalent recorded-CTF replay through ft_realtime_fileproxy;
- limited continuity, gap, dropped-sample, timing, artifact, and failure auditing;
- no unified configuration, logging, validation, or controlled resting-to-trial transition architecture.

CURRENT HANDOFF AND DIRECTION

I picked up the project in summer 2026 from Benjamin’s MATLAB/Brainstorm prototype, the existing scientific literature, and the intended left-IPS theta-neurofeedback objective defined with Dr. Baillet.

The current direction preserves Benjamin’s successful high-level concept while rebuilding it as a smaller, modular, auditable, and source-independent real-time program:

Brainstorm scientific preparation
→ validated participant-specific CombinedMatrix
→ simulated or live FieldTrip source
→ common chunk-processing pipeline
→ causal theta filtering
→ rolling 2-second IPS power calculation
→ resting baseline
→ trial z-score
→ Psychtoolbox expanding-circle feedback
→ complete logging and validation

The immediate milestone is a full recorded-CTF simulation using ft_realtime_fileproxy. Once the complete pipeline behaves correctly against a real replayed dataset, the same downstream program will connect to the MEG-room FieldTrip server, with the data source selected through configuration rather than by rewriting the algorithm.