Step 1B cleanup: offline reference stride and band diagnostics
==============================================================

Dense reference mode
--------------------
Dense mode computes one offline reference value for every one-sample shift of
the complete power window:

    window ends: W, W+1, W+2, ...

This is the most conservative gold-standard/debug mode. It is useful for short
datasets, edge-effect inspection, delay debugging, and tests that compare an
optimized reference against every possible window position.

Stepped reference mode
----------------------
Stepped mode computes offline reference values only at the window positions
that the simulated-online pipeline can output:

    window ends: W, W+S, W+2S, ...

For normal validation, S is the chunk length. This is scientifically valid for
simulated-online comparison because every stepped value still uses the full
PowerWindowSamples samples inside that window. The raw or filtered signal is not
downsampled, truncated, or shortened. The only skipped work is redundant window
positions between chunk outputs that will never be directly compared to a
streaming Measure.

Sample-index convention
-----------------------
Ref.SampleIndex remains equal to Ref.WindowCenterSample for backward
compatibility and direct comparison with Measure.WindowCenterSample.

Ref.WindowEndSample is stored separately for chunk-boundary diagnostics. Do not
reinterpret Ref.SampleIndex as the window end sample.

When to use each mode
---------------------
Use dense mode for:

    short debug runs,
    dense-vs-stepped equivalence tests,
    filter delay or edge-effect debugging.

Use stepped mode for:

    normal validation,
    long datasets,
    simulated-online offline-vs-streaming comparison.

Brainstorm tutorial validation
------------------------------
The Brainstorm Introduction tutorial config uses stepped reference mode by
default:

    RTConfig.Validation.Step1.ReferenceStrideMode = 'step'
    RTConfig.Validation.Step1.ReferenceStepSamples = RTConfig.ChunkSamples

For a 120 s, 600 Hz recording with 4 s power windows and 0.5 s chunks, this
prevents creation of tens of thousands of dense reference windows while keeping
the same full-window computation at each compared sample.

Band-detection diagnostics
--------------------------
Results.Step1.BandDetection stores official target-band sanity checks:

    target-band power mean, median, max, and standard deviation,
    whether target-band power is all zero or nonconstant,
    reference-band power summaries,
    offline reference power summaries,
    streaming power summaries,
    strongest PSD peak inside the configured search band,
    whether that peak falls inside the target band.

PASS means the target-band power is finite, nonzero, nonconstant, and has
conservative spectral support. WARN means some power exists but the diagnostic
is not strongly supported. FAIL means the target-band diagnostic is not usable.

Run the related tests
---------------------
From MATLAB:

    cd('C:\CODING\INTERNSHIPS\S_2026\NEUROSPEED_LAB\NEUROFEEDBACK\NEUROFEEDBACK_RT')
    startup
    run_all_tests

The key tests are:

    test_offline_reference_stepped_matches_dense
    test_band_detection_synthetic_positive
    test_band_detection_wrong_band_control
