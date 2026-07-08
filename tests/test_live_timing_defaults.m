function test_live_timing_defaults()
% TEST_LIVE_TIMING_DEFAULTS Check finalized live timing defaults.

%% ===== FINALIZE ACQUISITION-ONLY LIVE CONFIG =====
% Acquisition-only mode avoids requiring a precomputed matrix path here.
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Session.Mode = Modes.Session.LiveDiagnostics;
RTConfig.Debug.Verbose = false;

RTConfig = nf_finalize_config(RTConfig);

assert(RTConfig.Fs == 2400, 'Live Fs default changed.');
assert(RTConfig.ChunkSamples == 480, 'Live chunk sample count changed.');
assert(RTConfig.PowerWindowSamples == 4800, 'Live power-window sample count changed.');
assert(RTConfig.BufferSamples >= RTConfig.PowerWindowSamples, ...
    'Live buffer is shorter than the power window.');
assert(mod(RTConfig.PowerWindowSamples, RTConfig.ChunkSamples) == 0, ...
    'Power window should be an integer multiple of chunk size.');

end
