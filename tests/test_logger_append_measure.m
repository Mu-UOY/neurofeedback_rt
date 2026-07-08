function test_logger_append_measure()
% TEST_LOGGER_APPEND_MEASURE Check Measure schema normalization.

%% ===== INITIALIZE LOGGER =====
% Canonical and old partial Measures must append to one homogeneous array.
[RTConfig, cleanupObj] = local_temp_config(); %#ok<ASGLU>
Logger = nf_logger_init(RTConfig, 'mock_live_test', struct());

Measure = nf_measure_empty();
Measure.IsValid = false;
Measure.InvalidReason = 'warmup';
Measure.Power = NaN;
Measure.ZSmoothed = NaN;
Measure.FeedbackTargetRadiusPx = NaN;

Logger = nf_logger_append_measure(Logger, Measure);

assert(Logger.NMeasures == 1, 'Measure count did not increment.');
assert(numel(Logger.Measures) == 1, 'Measure row count mismatch.');
assert(isfield(Logger.Measures, 'FeedbackTargetRadiusPx'), ...
    'FeedbackTargetRadiusPx missing after append.');
assert(isnan(Logger.Measures(1).FeedbackTargetRadiusPx), ...
    'Runtime NaN feedback radius was not preserved.');
assert(strcmp(Logger.Measures(1).InvalidReason, 'warmup'), ...
    'InvalidReason was not preserved.');

OldMeasure = struct();
OldMeasure.Power = 1.23;
OldMeasure.IsValid = true;

Logger = nf_logger_append_measure(Logger, OldMeasure);

assert(Logger.NMeasures == 2, 'Old Measure was not appended.');
assert(numel(Logger.Measures) == 2, 'Old Measure did not normalize into array.');
assert(Logger.Measures(2).Power == 1.23, 'Old Measure Power was not preserved.');
assert(Logger.Measures(2).IsValid == true, 'Old Measure IsValid was not preserved.');
assert(isfield(Logger.Measures, 'FeedbackTargetRadiusPx'), ...
    'Canonical feedback field missing after old Measure append.');
assert(isnan(Logger.Measures(2).FeedbackTargetRadiusPx), ...
    'Missing old Measure feedback radius should be filled as NaN.');

end

function [RTConfig, cleanupObj] = local_temp_config()
tempProjectRoot = tempname();
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() local_rmdir(tempProjectRoot));
RTConfig = nf_mock_live_test_config();
RTConfig.Debug.Verbose = false;
RTConfig.Paths.ProjectRoot = tempProjectRoot;
end

function local_rmdir(pathToRemove)
if exist(pathToRemove, 'dir')
    rmdir(pathToRemove, 's');
end
end
