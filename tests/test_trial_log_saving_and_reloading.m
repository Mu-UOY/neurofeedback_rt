function test_trial_log_saving_and_reloading()
% TEST_TRIAL_LOG_SAVING_AND_RELOADING Check saved trial MAT content.

%% ===== RUN SHORT TRIAL =====
% Use temporary output directories for the saved baseline and trial log.
[RTConfig, cleanupObj] = local_config_with_temp_data(); %#ok<ASGLU>
[Baseline, ~, RTConfig] = nf_run_resting(RTConfig);
RTConfig.Baseline.Path = Baseline.OutputFile;
[Measures, TrialSummary, ~] = nf_run_trial(RTConfig);

%% ===== LOAD SAVED TRIAL =====
% The saved MAT should include Measures, TrialSummary, and Baseline.
loaded = load(TrialSummary.OutputFile);
assert(isfield(loaded, 'Measures'), 'Saved trial missing Measures.');
assert(isfield(loaded, 'TrialSummary'), 'Saved trial missing TrialSummary.');
assert(isfield(loaded, 'Baseline'), 'Saved trial missing Baseline.');
assert(numel(loaded.Measures) == numel(Measures), 'Loaded Measure count mismatch.');
assert(exist(loaded.TrialSummary.OutputFile, 'file') ~= 0, 'TrialSummary.OutputFile does not exist.');

valid = [loaded.Measures.IsValid] == true;
assert(any(valid), 'Loaded trial has no valid Measures.');
assert(all(isfinite([loaded.Measures(valid).ZRaw])), 'Loaded ZRaw values are not finite.');
assert(all(isfinite([loaded.Measures(valid).ZClipped])), 'Loaded ZClipped values are not finite.');
assert(all(isfinite([loaded.Measures(valid).ZSmoothed])), 'Loaded ZSmoothed values are not finite.');

end

function [RTConfig, cleanupObj] = local_config_with_temp_data()
% Build an isolated config and saved synthetic dataset.
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_rmdir(tempRoot));

Fs = 100;
nSamples = 800;
t = (0:(nSamples - 1)) ./ Fs;
amp = 1 + 0.25 .* sin(2 .* pi .* 0.25 .* t);
X = amp .* sin(2 .* pi .* 10 .* t);
Time = t; %#ok<NASGU>
ChannelNames = {'CH001'}; %#ok<NASGU>
dataFile = fullfile(tempRoot, 'synthetic_data.mat');
save(dataFile, 'X', 'Fs', 'Time', 'ChannelNames');

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.DatasetPath = dataFile;
RTConfig.Fs = Fs;
RTConfig.Filter.Type = 'none';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.TargetBand = [8 12];
RTConfig.ChunkSamples = 20;
RTConfig.PowerWindowSamples = 40;
RTConfig.BufferSamples = 100;
RTConfig.Baseline.MinValidWindows = 3;
RTConfig.Baseline.OutlierMethod = 'none';
RTConfig.Baseline.RequireConfigHashMatch = true;
RTConfig.Feedback.Mode = 'debug_value';

RTConfig.Paths.OutputDir = tempRoot;
RTConfig.Paths.BaselinesDir = fullfile(tempRoot, 'baselines');
RTConfig.Paths.TrialsDir = fullfile(tempRoot, 'trials');
RTConfig.Paths.ValidationDir = fullfile(tempRoot, 'validation');
end

function local_rmdir(pathToRemove)
if exist(pathToRemove, 'dir')
    rmdir(pathToRemove, 's');
end
end
