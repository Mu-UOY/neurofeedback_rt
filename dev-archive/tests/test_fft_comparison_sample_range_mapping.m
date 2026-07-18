function test_fft_comparison_sample_range_mapping()
% TEST_FFT_COMPARISON_SAMPLE_RANGE_MAPPING Check non-1-based sample ranges.

%% ===== BUILD SYNTHETIC DATA =====
% The sample range intentionally starts away from one to test mapping.
rng(13);
Fs = 1200;
t = 0:(1 / Fs):(10 - 1 / Fs);
nSamples = numel(t);
X = [
    sin(2 * pi * 6 * t) + 0.05 * randn(size(t));
    0.20 * randn(size(t));
    0.20 * randn(size(t))];

Data = struct();
Data.X = X;
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001','CH002','CH003'};
Data.Events = [];
Data.Metadata.SampleRange = [5001, 5001 + nSamples - 1];

%% ===== CONFIGURE VALIDATION =====
% Use identity projection so sample-index mapping is the only variable.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Spatial.NChannels = 3;
RTConfig.Spatial.Mode = 'identity';
RTConfig.TargetBand = [4 8];
RTConfig.PowerWindowSamples = round(2.0 * Fs);
RTConfig.BufferSamples = round(4.0 * Fs);
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = round(0.5 * Fs);

Ref = nf_make_offline_reference(Data, RTConfig);

% This manually converts Ref sample fields to acquisition indices to test
% nf_validate_fft_comparison mapping behavior. A later Step 1B cleanup may
% make nf_make_offline_reference emit acquisition-indexed samples directly.
offset = Data.Metadata.SampleRange(1) - 1;
Ref.WindowStartSample = Ref.WindowStartSample + offset;
Ref.WindowEndSample = Ref.WindowEndSample + offset;
Ref.WindowCenterSample = Ref.WindowCenterSample + offset;
Ref.SampleIndex = Ref.SampleIndex + offset;
Ref.Time = Ref.SampleIndex ./ RTConfig.Fs;

Results = nf_validate_fft_comparison(Data, Ref, RTConfig);

%% ===== ASSERT ACQUISITION SAMPLE MAPPING =====
% Acquisition samples must be mapped back to local columns before indexing.
assert(ismember(Results.Status, {'PASS','WARN'}), 'FFT comparison did not complete successfully.');
assert(~isempty(Results.WindowedFFT.Power), 'Windowed FFT power is empty.');
assert(all(Results.WindowedFFT.WindowStartSample >= Data.Metadata.SampleRange(1)), ...
    'Window starts are outside the configured acquisition range.');
assert(all(Results.WindowedFFT.WindowEndSample <= Data.Metadata.SampleRange(2)), ...
    'Window ends are outside the configured acquisition range.');
assert(all(isfinite(Results.WindowedFFT.Power)), 'Windowed FFT power contains nonfinite values.');

end
