function test_step3d_trial_failsafe_disabled_does_not_report_hard_failsafe()
% TEST_STEP3D_TRIAL_FAILSAFE_DISABLED_DOES_NOT_REPORT_HARD_FAILSAFE Check optional failsafe.

%% ===== PREPARE SHORT TEST TRIAL =====
% TestMaxIterations is a test-only guard and must not be reported as hard_failsafe.
Modes = nf_modes();
[RTConfig, tempRoot] = nf_test_live_self_test_config();
cleanupObj = onCleanup(@() local_cleanup(tempRoot));

RTConfig.Safety.UseMaxDurationFailsafe = false;
RTConfig.Safety.EnableStopFile = false;
RTConfig.Safety.EnableKeyboardStop = false;
RTConfig.LiveTrial.TestMaxIterations = 2;
RTConfig.Protocol.Trial.Success.Enabled = false;
RTConfig.LiveTrial.RequireAtLeastOneValidMeasure = false;
RTConfig.LiveTrial.RequireAtLeastOneFeedbackUpdate = false;
RTConfig.Feedback.Mode = Modes.Feedback.None;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.None;

Baseline = local_baseline(RTConfig);

%% ===== RUN TRIAL =====
TrialResult = nf_run_live_trial(RTConfig, [], [], Baseline);

assert(~strcmp(TrialResult.StopReason, Modes.StopReason.HardFailsafe), ...
    'Disabled failsafe was reported as hard_failsafe.');
assert(strcmp(TrialResult.StopReason, Modes.StopReason.CompletedUnknown), ...
    'Disabled failsafe test guard should leave completed_unknown stop reason.');
assert(isfield(TrialResult, 'SafetySummary'), 'Safety summary missing.');
assert(TrialResult.SafetySummary.UseMaxDurationFailsafe == false, ...
    'Safety summary did not record disabled failsafe.');

clear cleanupObj
end

function Baseline = local_baseline(RTConfig)
% Build a finalized, nondegenerate baseline for trial z-scoring.
values = 1:RTConfig.Baseline.MinValidWindows;
Baseline = struct();
Baseline.Type = 'baseline';
Baseline.Partial = false;
Baseline.Finalized = true;
Baseline.Mean = mean(values);
Baseline.Std = std(values);
Baseline.Values = values;
Baseline.TrimmedValues = values;
Baseline.ValidWindowCount = numel(values);
Baseline.UsableWindowCount = numel(values);
end

function local_cleanup(tempRoot)
% Remove temporary self-test output root.
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
