function test_brainstorm_iir_sos_bst_function_synthetic()
% TEST_BRAINSTORM_IIR_SOS_BST_FUNCTION_SYNTHETIC Check direct Brainstorm path.

cleanupObj = onCleanup(@() close(findall(0, 'Type', 'figure'))); %#ok<NASGU>
close(findall(0, 'Type', 'figure'));

%% ===== SKIP IF BRAINSTORM IS UNAVAILABLE =====
% Portable test runs should not fail when Brainstorm is not installed/on path.
if exist('process_bandpass', 'file') == 0 && exist('bst_bandpass_hfilter', 'file') == 0 && ...
        exist('brainstorm', 'file') == 0
    fprintf('[SKIP] Brainstorm functions unavailable for bst_function synthetic test.\n');
    return;
end

%% ===== BUILD SYNTHETIC DATA =====
% Amplitude-modulated alpha produces a stable windowed bandpower trend.
rng(101);
Fs = 600;
durationSec = 60;
t = (0:(durationSec * Fs - 1)) ./ Fs;
amp = 1 + 0.6 .* sin(2 .* pi .* 0.08 .* t);
Data = struct();
Data.X = amp .* sin(2 .* pi .* 10 .* t) + 0.05 .* randn(size(t));
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001'};
Data.Events = [];
Data.Metadata = struct();

%% ===== CONFIGURE DIRECT BRAINSTORM COMPARISON =====
% RequireForPass=true means available Brainstorm must actually filter.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.TargetBand = [8 12];
RTConfig.ChunkSamples = round(0.5 .* Fs);
RTConfig.PowerWindowSamples = round(4 .* Fs);
RTConfig.BufferSamples = round(8 .* Fs);
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.Filter.Type = 'iir_sos';
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.Brainstorm.Mode = 'bst_function';
RTConfig.Validation.Step1.Brainstorm.RequireForPass = true;
RTConfig.Brainstorm.OfflineBandpassMethod = 'bst-hfilter-2019';

Ref = nf_make_offline_reference(Data, RTConfig);
Results = nf_validate_iir_sos_comparison(Data, Ref, RTConfig);
close(findall(0, 'Type', 'figure'));

%% ===== CHECK BRAINSTORM COMPARISON =====
% The direct Brainstorm path must run and agree with the IIR/SOS trend.
assert(~strcmp(Results.Status, 'SKIPPED'), 'bst_function synthetic comparison was SKIPPED.');
assert(strcmp(Results.Status, 'PASS'), 'bst_function synthetic comparison did not PASS.');
assert(Results.Compare.ZCorrelation >= 0.90, ...
    'ZCorrelation %.6f is below 0.90.', Results.Compare.ZCorrelation);
assert(isfield(Results.BrainstormInfo, 'Mode') && ...
    strcmp(Results.BrainstormInfo.Mode, 'bst_function'), ...
    'BrainstormInfo.Mode did not record bst_function.');
assert(isfield(Results.BrainstormInfo, 'FunctionName') && ...
    ~isempty(Results.BrainstormInfo.FunctionName), ...
    'BrainstormInfo.FunctionName is missing.');
assert(isempty(findall(0, 'Type', 'figure')), ...
    'Brainstorm synthetic test left a figure open.');

end
