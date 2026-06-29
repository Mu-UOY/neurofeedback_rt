function test_zscore_computation_from_saved_baseline()
% TEST_ZSCORE_COMPUTATION_FROM_SAVED_BASELINE Check resting-to-trial z-scoring.

%% ===== CREATE TEMPORARY DATASET =====
% Use isolated output folders so the test does not touch real baselines/trials.
[RTConfig, cleanupObj] = local_config_with_temp_data(); %#ok<ASGLU>

%% ===== RUN RESTING THEN TRIAL =====
% The same config is used so the saved baseline hash matches the trial config.
[Baseline, ~, RTConfig] = nf_run_resting(RTConfig);
RTConfig.Baseline.Path = Baseline.OutputFile;
[Measures, TrialSummary, ~] = nf_run_trial(RTConfig);

%% ===== CHECK Z-SCORE AND FEEDBACK VALUES =====
valid = [Measures.IsValid] == true;
assert(any(valid), 'Trial produced no valid Measures.');
assert(all(isfinite([Measures(valid).ZRaw])), 'Valid Measures have nonfinite ZRaw.');
assert(all(isfinite([Measures(valid).ZClipped])), 'Valid Measures have nonfinite ZClipped.');
assert(all(isfinite([Measures(valid).ZSmoothed])), 'Valid Measures have nonfinite ZSmoothed.');
clipRange = RTConfig.ZScore.ClipRange;
assert(all([Measures(valid).ZClipped] >= clipRange(1) & [Measures(valid).ZClipped] <= clipRange(2)), ...
    'ZClipped exceeded configured clip range.');
assert(any(isfinite([Measures.FeedbackValue])), 'Expected finite debug FeedbackValue.');
assert(TrialSummary.NFeedbackValues > 0, 'TrialSummary did not count feedback values.');
assert(numel(unique(round([Measures(valid).ZSmoothed], 12))) > 1, ...
    'ZSmoothed did not progress across valid chunks.');

end

function [RTConfig, cleanupObj] = local_config_with_temp_data()
% Build an isolated config and saved synthetic dataset.
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_rmdir(tempRoot));

Fs = 100;
nSamples = 1000;
t = (0:(nSamples - 1)) ./ Fs;
amp = 1 + 0.35 .* sin(2 .* pi .* 0.2 .* t);
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
RTConfig.Feedback.UpdateEveryNValidMeasures = 1;

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
