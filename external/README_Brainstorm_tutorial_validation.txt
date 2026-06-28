Brainstorm Introduction tutorial raw-MEG validation
===================================================

Purpose
-------
This Step 1B bridge exports raw MEG from the Brainstorm Introduction CTF
tutorial dataset into the neurofeedback_rt validation MAT format, then runs
the existing Step 1 offline scientific-validation pipeline on that raw data.

This is a raw-data bridge only. It does not implement live MEG, FieldTrip
buffer streaming, Brainstorm realtime, feedback UI, baseline/trial protocol,
stim-computer communication, artifact projectors, inverse kernels, or scout
mapping.

Local paths used for this validation
------------------------------------
Brainstorm root:
    C:\Users\yango\Documents\brainstorm3

FieldTrip root:
    C:\Users\yango\Documents\fieldtrip

Raw CTF dataset folder:
    C:\Users\yango\Documents\sample_introduction\data\S01_AEF_20131218_01_600Hz.ds

Recommended MATLAB commands
---------------------------
cd('C:\CODING\INTERNSHIPS\S_2026\NEUROSPEED_LAB\NEUROFEEDBACK\NEUROFEEDBACK_RT')
startup

addpath('C:\Users\yango\Documents\fieldtrip')
ft_defaults

addpath('C:\Users\yango\Documents\brainstorm3')

[Results, Ref, Measures, RTConfig] = nf_run_brainstorm_intro_validation();

The project source does not hardcode these toolbox paths. Keep any personal
path setup in local_startup_toolboxes.m or in the MATLAB session, not in
committed source files.

Export behavior
---------------
The default runner exports 0 to 120 seconds from the raw CTF folder into:

    outputs\validation\bst_intro_run1_meg_0_120s.mat

The default export target is MEG channels only. The bridge uses FieldTrip's raw
reader path and intentionally applies no filters, detrending, demeaning,
baseline correction, artifact correction, inverse modeling, or scout mapping.

The default validation target band is alpha, [8 12] Hz. This is a sanity check
for the raw-tutorial bridge and the existing Step 1 offline validation tools.

What success means
------------------
A successful run means:

    1. The raw CTF tutorial data can be exported into the canonical validation
       MAT structure.
    2. The existing simulated-online validation pipeline can replay that raw
       data without using synthetic data.
    3. The Step 1 FFT and IIR/SOS checks run on real tutorial MEG data.

What success does not mean
--------------------------
Success here does not validate a live acquisition path, feedback display,
Brainstorm realtime integration, source-space feedback, trial timing,
stimulation timing, artifact projectors, or baseline/trial z-score protocol.
