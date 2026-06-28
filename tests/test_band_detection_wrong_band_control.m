function test_band_detection_wrong_band_control()
% TEST_BAND_DETECTION_WRONG_BAND_CONTROL Check wrong-band negative control.
%
% USAGE:  test_band_detection_wrong_band_control()
%
% DESCRIPTION:
%     Uses the same deterministic 10 Hz signal as the positive control but
%     validates a non-alpha target band. The main PSD peak must not be marked
%     as inside the wrong target band.

%% ===== RUN WRONG-BAND CONTROL =====
% A 10 Hz signal should not make a 15-19 Hz target look like the main peak.
[Results, ~, ~] = local_run_synthetic_band_detection([15 19]);

%% ===== CHECK NEGATIVE CONTROL =====
% The diagnostic may warn or fail, but it must not pass as a target peak.
assert(abs(Results.PeakFrequency - 10) < 0.75, 'Peak frequency should still reflect the 10 Hz signal.');
assert(Results.PeakInsideTargetBand == false, 'Wrong target band should not contain the main peak.');
assert(~strcmp(Results.Status, 'PASS'), 'Wrong-band control should not pass.');

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
