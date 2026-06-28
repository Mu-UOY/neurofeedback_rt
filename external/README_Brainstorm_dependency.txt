Brainstorm dependency notes
==========================

The first runnable validation path defaults to RTConfig.Filter.Type = 'iir_sos'.
That mode does not require Brainstorm, but it does require MATLAB's Signal
Processing Toolbox functions butter and sosfilt.

Runtime Brainstorm FIR mode is available through:

    RTConfig.Filter.Type = 'brainstorm_fir'

For that runtime mode, RTConfig.Brainstorm.FilterSpecPath is currently required.
The file must be a MAT file containing one of:

1. FiltSpec.b and optional FiltSpec.a
2. FilterSpec.b and optional FilterSpec.a
3. top-level b and optional top-level a

Direct runtime calls to bst_bandpass_hfilter are not wired until the local
function signature is manually verified. Setting only RTConfig.Brainstorm.Path
is not sufficient for runtime brainstorm_fir mode.

Step 1A Brainstorm-style offline comparison can still use:

1. precomputed_filtered
2. filter_spec
3. iir_self_test
4. skip

The project uses FIR coefficients causally through filter(), not through
offline zero-phase filtering. This keeps the validation path comparable to the
simulated-online streaming implementation.
