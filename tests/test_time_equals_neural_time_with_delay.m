function test_time_equals_neural_time_with_delay()
% TEST_TIME_EQUALS_NEURAL_TIME_WITH_DELAY Measure.Time must report neural time.
%
% USAGE:  test_time_equals_neural_time_with_delay()
%
% DESCRIPTION:
%     Forces a filter delay correction and verifies Measure.Time follows the
%     corrected neural-window time rather than the raw window-center time.

%% ===== CONFIGURE PIPELINE =====
% No filter is applied, then delay correction is set manually on RT.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Filter.Type = 'none';
RTConfig.Fs = 100;
RTConfig.ChunkSamples = 10;
RTConfig.PowerWindowSamples = 10;
RTConfig.BufferSamples = 20;
RTConfig.Spatial.NChannels = 1;

RT = nf_rt_prepare(RTConfig);
RT.Filter.DelayCorrectionUsed = 4;

%% ===== BUILD CHUNK AND DIAGNOSTICS =====
% Chunk sample range creates a raw center distinct from the corrected center.
chunk = struct();
chunk.Data = zeros(1, 10);
chunk.SampleIndex = 101;
chunk.SampleIndices = 101:110;
chunk.NSamples = 10;
chunk.SourceMode = 'simulated_online';
chunk.Timestamp = NaN;

Diagnostics = struct();
Diagnostics.InvalidReason = '';
Diagnostics.GapInWindowFlag = false;
Diagnostics.DroppedChunkFlag = false;

%% ===== MAKE DELAY-CORRECTED MEASURE =====
% The timestamp helper should use corrected sample indices.
Measure = nf_rt_make_measure(1, 1, true, Diagnostics, chunk, RT, RTConfig);

%% ===== CHECK TIME CONVENTION =====
% Measure.Time should match neural time, not raw acquisition-centered time.
rawTime = Measure.WindowCenterSample ./ RTConfig.Fs;
assert(Measure.Time == Measure.NeuralWindowTime, 'Measure.Time must equal Measure.NeuralWindowTime.');
assert(Measure.Time ~= rawTime, 'Measure.Time incorrectly used raw window-center time.');

end
