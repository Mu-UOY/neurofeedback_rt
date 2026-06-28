function test_band_detection_synthetic_positive()
% TEST_BAND_DETECTION_SYNTHETIC_POSITIVE Check 10 Hz target-band detection.
%
% USAGE:  test_band_detection_synthetic_positive()
%
% DESCRIPTION:
%     Uses a deterministic amplitude-modulated 10 Hz signal and verifies that
%     band diagnostics identify the alpha target band.

%% ===== RUN BAND DETECTION =====
% The helper returns Data, Ref, config, and diagnostics for the positive case.
[Results, ~, ~] = local_run_synthetic_band_detection([8 12]);

%% ===== CHECK POSITIVE CONTROL =====
% The strongest 1-60 Hz peak should be close to 10 Hz and inside alpha.
assert(~strcmp(Results.Status, 'FAIL'), 'Positive control should not fail.');
assert(abs(Results.PeakFrequency - 10) < 0.75, 'Peak frequency is not close to 10 Hz.');
assert(Results.PeakInsideTargetBand == true, 'Peak should be inside the target band.');
assert(isfinite(Results.TargetPowerMean), 'Target power mean is not finite.');
assert(~Results.TargetPowerAllZero, 'Target power should be nonzero.');
assert(Results.TargetPowerNonconstant, 'Amplitude modulation should make target power nonconstant.');

end

function [Results, Ref, RTConfig] = local_run_synthetic_band_detection(targetBand)
% Build a deterministic 10 Hz dataset and run official band diagnostics.
rng(42);
Fs = 600;
durationSeconds = 12;
t = (0:(durationSeconds .* Fs - 1)) ./ Fs;
amplitude = 1 + 0.35 .* sin(2 .* pi .* 0.25 .* t);
X = amplitude .* sin(2 .* pi .* 10 .* t) + 0.02 .* randn(size(t));

Data = struct();
Data.X = X;
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001'};
Data.Events = [];

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Filter.Type = 'iir_sos';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.TargetBand = targetBand;
RTConfig.PowerWindowSamples = round(2.0 .* Fs);
RTConfig.ChunkSamples = round(0.5 .* Fs);
RTConfig.BufferSamples = round(4.0 .* Fs);
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.ReferenceStrideMode = 'step';
RTConfig.Validation.Step1.ReferenceStepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.Brainstorm.Mode = 'skip';

Ref = nf_make_offline_reference(Data, RTConfig);
FFTResults = nf_validate_fft_comparison(Data, Ref, RTConfig);
Results = nf_validate_band_detection(Data, Ref, [], RTConfig, FFTResults);
end
