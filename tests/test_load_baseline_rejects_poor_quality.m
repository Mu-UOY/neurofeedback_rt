function test_load_baseline_rejects_poor_quality()
% TEST_LOAD_BASELINE_REJECTS_POOR_QUALITY Check load-time quality rejection.

%% ===== CREATE POOR FINALIZED BASELINE =====
% The baseline is structurally finalized but numerically unusable.
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_rmdir(tempRoot)); %#ok<NASGU>
baselineFile = fullfile(tempRoot, 'baseline_poor.mat');

Baseline = struct();
Baseline.Type = 'baseline';
Baseline.Partial = false;
Baseline.Finalized = true;
Baseline.Mean = NaN;
Baseline.Std = NaN;
Baseline.Values = [];
Baseline.TrimmedValues = [];
Baseline.ValidWindowCount = 0;
Baseline.UsableWindowCount = 0;
Baseline.ConfigHash = '';
save(baselineFile, 'Baseline');

%% ===== LOAD THROUGH BASELINE API =====
% Disable hash matching so the test isolates quality checking.
RTConfig = nf_default_config();
RTConfig.Baseline.Path = baselineFile;
RTConfig.Baseline.RequireConfigHashMatch = false;
RTConfig.Paths.OutputDir = tempRoot;
RTConfig.Paths.BaselinesDir = tempRoot;

didError = false;
try
    nf_load_baseline(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'quality failed'), ...
        'Unexpected load-baseline error: %s', ME.message);
end

assert(didError, 'nf_load_baseline accepted a poor-quality finalized baseline.');

end

function local_rmdir(pathToRemove)
if exist(pathToRemove, 'dir')
    rmdir(pathToRemove, 's');
end
end
