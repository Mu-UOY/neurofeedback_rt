function test_zsmooth_state_update()
% TEST_ZSMOOTH_STATE_UPDATE Ensure smoothing state updates per valid chunk.
%
% USAGE:  test_zsmooth_state_update()
%
% DESCRIPTION:
%     Runs two valid Measures through z-score smoothing and verifies raw,
%     smoothed, and state-update values.

%% ===== CONFIGURE BASELINE STATE =====
% Mean 10 and std 2 make expected z-scores easy to compute.
RTConfig = nf_default_config();
RTConfig.ZScore.SmoothAlpha = 0.5;

RT = nf_rt_init_schema();
RT.HasBaseline = true;
RT.ZSmoothState.Alpha = RTConfig.ZScore.SmoothAlpha;
RT.Baseline.Mean = 10;
RT.Baseline.Std = 2;

%% ===== PROCESS FIRST MEASURE =====
% First valid z-score initializes smoothing state directly.
Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.Power = 12;
Measure.SampleIndex = 1;
[Measure, RT] = nf_rt_compute_zscore(Measure, RT, RTConfig);

assert(abs(Measure.ZRaw - 1) < 1e-12, 'Unexpected first raw z-score.');
assert(abs(Measure.ZSmoothed - 1) < 1e-12, 'Unexpected first smoothed z-score.');
assert(RT.ZSmoothState.Initialized, 'Smoothing state was not initialized.');

%% ===== PROCESS SECOND MEASURE =====
% Second z-score should blend with the previous smoothed value.
Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.Power = 14;
Measure.SampleIndex = 2;
[Measure, RT] = nf_rt_compute_zscore(Measure, RT, RTConfig);

assert(abs(Measure.ZRaw - 2) < 1e-12, 'Unexpected second raw z-score.');
assert(abs(Measure.ZSmoothed - 1.5) < 1e-12, 'Unexpected second smoothed z-score.');
assert(RT.ZSmoothState.LastUpdateSample == 2, 'Unexpected smoothing update sample.');

end
