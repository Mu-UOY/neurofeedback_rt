function test_config_hash_rejects_incompatible_baseline()
% TEST_CONFIG_HASH_REJECTS_INCOMPATIBLE_BASELINE Check baseline hash enforcement.

%% ===== CREATE ISOLATED BASELINE =====
% Save a valid baseline with one computational config.
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_rmdir(tempRoot)); %#ok<NASGU>

RTConfig = local_hash_config(tempRoot);
RT = nf_rt_prepare(RTConfig);
BaselineAcc = nf_baseline_init(RTConfig, RT);
for powerValue = [1 2 3 4]
    Measure = nf_measure_empty();
    Measure.IsValid = true;
    Measure.Power = powerValue;
    BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig);
end
BaselineAcc = nf_baseline_reject_outliers(BaselineAcc, RTConfig);
Baseline = nf_baseline_finalize(BaselineAcc, RTConfig);
Baseline.Quality = nf_baseline_check_quality(Baseline, RTConfig);
baselineFile = nf_save_baseline(Baseline, RTConfig);

%% ===== REQUIRE HASH MATCH =====
% Changing target band should make the baseline incompatible.
BadConfig = RTConfig;
BadConfig.TargetBand = [12 18];
BadConfig.Baseline.Path = baselineFile;
BadConfig.Baseline.RequireConfigHashMatch = true;

didError = false;
try
    nf_load_baseline(BadConfig);
catch ME
    didError = contains(ME.message, 'hash mismatch');
end
assert(didError, 'Hash mismatch baseline was not rejected.');

%% ===== ALLOW HASH MISMATCH WHEN REQUESTED =====
% RequireConfigHashMatch=false should permit loading the same baseline.
BadConfig.Baseline.RequireConfigHashMatch = false;
loadedBaseline = nf_load_baseline(BadConfig);
assert(strcmp(loadedBaseline.Type, 'baseline'), 'Baseline did not load when hash check disabled.');

end

function RTConfig = local_hash_config(tempRoot)
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.Mode = 'simulated_resting';
RTConfig.Fs = 100;
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
