function test_fft_comparison_detects_injected_theta()
% TEST_FFT_COMPARISON_DETECTS_INJECTED_THETA Check synthetic 6 Hz bandpower.

%% ===== BUILD SYNTHETIC DATA =====
% Channel 1 carries a strong 6 Hz rhythm; channels 2-3 are broadband noise.
rng(10);
Fs = 1200;
t = 0:(1 / Fs):(10 - 1 / Fs);
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
Data.Metadata = struct();

%% ===== CONFIGURE STEP 1 FFT VALIDATION =====
% Use a theta-appropriate two-second window and identity spatial projection.
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
Results = nf_validate_fft_comparison(Data, Ref, RTConfig);

%% ===== ASSERT TARGET-BAND DETECTION =====
% The injected channel must dominate target-band power.
assert(ismember(Results.Status, {'PASS','WARN'}), 'FFT comparison did not complete successfully.');
assert(all(isfinite(Results.BandPower.Target.PowerPerSignal)), 'Target-band power contains nonfinite values.');
assert(Results.BandPower.Target.PowerPerSignal(1) > ...
    mean(Results.BandPower.Target.PowerPerSignal(2:3)), ...
    'Injected 6 Hz channel did not show stronger target-band power.');

end
