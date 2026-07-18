function test_iir_sos_comparison_self_reference()
% TEST_IIR_SOS_COMPARISON_SELF_REFERENCE Compare IIR/SOS against itself.

%% ===== BUILD SYNTHETIC DATA =====
% Amplitude modulation avoids a degenerate constant power trace.
rng(11);
Fs = 1200;
t = 0:(1 / Fs):10;
amp = 1 + 0.25 * sin(2 * pi * 0.5 * t);
x = amp .* sin(2 * pi * 6 * t) + 0.05 * randn(size(t));

Data = struct();
Data.X = x;
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001'};
Data.Events = [];
Data.Metadata = struct();

%% ===== CONFIGURE SELF-REFERENCE MODE =====
% iir_self_test exists only to test comparison/alignment machinery.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Spatial.NChannels = 1;
RTConfig.Spatial.Mode = 'identity';
RTConfig.TargetBand = [4 8];
RTConfig.PowerWindowSamples = round(2.0 * Fs);
RTConfig.BufferSamples = round(4.0 * Fs);
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = round(0.5 * Fs);
RTConfig.Validation.Step1.Brainstorm.Mode = 'iir_self_test';
RTConfig.Validation.Step1.Brainstorm.RequireForPass = true;

Ref = nf_make_offline_reference(Data, RTConfig);
Results = nf_validate_iir_sos_comparison(Data, Ref, RTConfig);

%% ===== ASSERT NEAR-PERFECT AGREEMENT =====
% Identical filtered traces should align and correlate almost perfectly.
assert(strcmp(Results.Status, 'PASS'), 'IIR/SOS self-reference comparison did not pass.');
assert(Results.Compare.NCompared > 0, 'No windows were compared.');
assert(Results.Compare.ZCorrelation > 0.999, ...
    'IIR/SOS self-reference z-correlation was unexpectedly low.');

end
