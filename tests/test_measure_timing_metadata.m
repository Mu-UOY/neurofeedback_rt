function test_measure_timing_metadata()
% TEST_MEASURE_TIMING_METADATA Check raw and corrected timing fields.
%
% USAGE:  test_measure_timing_metadata()
%
% DESCRIPTION:
%     Builds a single valid Measure without filter delay and verifies raw,
%     corrected, and time fields are populated consistently.

%% ===== CONFIGURE NO-DELAY PIPELINE =====
% Filter.Type none makes raw and corrected window centers identical.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Filter.Type = 'none';
RTConfig.Fs = 100;
RTConfig.ChunkSamples = 4;
RTConfig.PowerWindowSamples = 4;
RTConfig.BufferSamples = 8;
RTConfig.Spatial.NChannels = 1;

RT = nf_rt_prepare(RTConfig);

%% ===== BUILD CHUNK AND DIAGNOSTICS =====
% One chunk exactly fills the power window.
chunk = struct();
chunk.Data = zeros(1, 4);
chunk.SampleIndex = 1;
chunk.SampleIndices = 1:4;
chunk.NSamples = 4;
chunk.SourceMode = 'simulated_online';
chunk.Timestamp = NaN;

Diagnostics = struct();
Diagnostics.InvalidReason = '';
Diagnostics.GapInWindowFlag = false;
Diagnostics.DroppedChunkFlag = false;

%% ===== MAKE MEASURE =====
% Power inputs are valid so timing fields should be populated.
Measure = nf_rt_make_measure(1, 1, true, Diagnostics, chunk, RT, RTConfig);

%% ===== CHECK TIMING FIELDS =====
% With no delay, corrected and uncorrected window centers match.
assert(Measure.WindowStartSample == 1, 'Unexpected window start sample.');
assert(Measure.WindowEndSample == 4, 'Unexpected window end sample.');
assert(Measure.WindowCenterSample == 3, 'Unexpected window center sample.');
assert(Measure.CorrectedWindowCenterSample == 3, 'Unexpected corrected center sample.');
assert(abs(Measure.Time - 0.03) < 1e-12, 'Unexpected Measure.Time.');
assert(abs(Measure.NeuralWindowTime - 0.03) < 1e-12, 'Unexpected neural window time.');

end
