function test_brainstorm_intro_validation_config()
% TEST_BRAINSTORM_INTRO_VALIDATION_CONFIG Check tutorial validation defaults.
%
% USAGE:  test_brainstorm_intro_validation_config()
%
% DESCRIPTION:
%     Verifies the Brainstorm Introduction validation config without requiring
%     FieldTrip, Brainstorm, or the raw CTF tutorial dataset.

%% ===== BUILD CONFIG =====
% Use representative tutorial sampling and MEG channel count.
Fs = 600;
nChannels = 274;
RTConfig = nf_brainstorm_intro_validation_config('fake_path.mat', Fs, nChannels);

%% ===== CHECK SOURCE AND TARGET BAND =====
% The helper should set the dataset path and alpha target band.
assert(strcmp(RTConfig.Source.DatasetPath, 'fake_path.mat'), 'Dataset path not set.');
assert(isequal(RTConfig.TargetBand, [8 12]), 'Unexpected target band.');

%% ===== CHECK FILTER AND SPATIAL SETTINGS =====
% Step 1B uses the project IIR/SOS path and identity spatial mapping.
assert(strcmp(RTConfig.Filter.Type, 'iir_sos'), 'Unexpected filter type.');
assert(strcmp(RTConfig.Spatial.Mode, 'identity'), 'Unexpected spatial mode.');
assert(RTConfig.Spatial.NChannels == nChannels, 'Unexpected channel count.');

%% ===== CHECK WINDOW SIZES =====
% Tutorial validation uses 0.5 s chunks, 4 s power windows, and 8 s buffers.
assert(RTConfig.ChunkSamples == round(0.5 .* Fs), 'Unexpected chunk length.');
assert(RTConfig.PowerWindowSamples == round(4.0 .* Fs), 'Unexpected power window length.');
assert(RTConfig.BufferSamples == round(8.0 .* Fs), 'Unexpected buffer length.');

%% ===== CHECK STEP 1 SETTINGS =====
% Brainstorm comparison is skipped in this raw-reader bridge.
assert(RTConfig.Validation.Step1.WindowSamples == RTConfig.PowerWindowSamples, ...
    'Unexpected Step 1 window length.');
assert(RTConfig.Validation.Step1.StepSamples == RTConfig.ChunkSamples, ...
    'Unexpected Step 1 step length.');
assert(strcmp(RTConfig.Validation.Step1.ReferenceStrideMode, 'step'), ...
    'Brainstorm tutorial validation should use stepped references.');
assert(RTConfig.Validation.Step1.ReferenceStepSamples == RTConfig.ChunkSamples, ...
    'Unexpected reference step length.');
assert(strcmp(RTConfig.Validation.Step1.Brainstorm.Mode, 'skip'), ...
    'Brainstorm comparison should be skipped.');
assert(RTConfig.Validation.Step1.BandDetection.Enable == true, ...
    'Band detection should be enabled.');
assert(RTConfig.Validation.Step1.Controls.Enable == false, ...
    'Synthetic controls should not run inside the tutorial config.');

expectedBands = [
    4 8
    8 12
    13 30
    30 59
];
assert(isequal(RTConfig.Validation.Step1.FFT.ReferenceBands, expectedBands), ...
    'Unexpected FFT reference bands.');

end
