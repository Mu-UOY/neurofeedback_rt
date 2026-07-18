function test_step3d_trial_cleanup_on_feedback_update_error()
% TEST_STEP3D_TRIAL_CLEANUP_ON_FEEDBACK_UPDATE_ERROR Check cleanup on display error.

%% ===== PREPARE SHADOWED FEEDBACK UPDATE =====
[RTConfig, tempRoot] = nf_test_live_self_test_config();
RTConfig.LiveTrial.SavePartialEveryNMeasures = 1;
RTConfig.Logging.FlushEveryNMeasures = 1;
Baseline = local_baseline(RTConfig);
[shadowDir, cleanupShadow] = local_shadow_function('nf_feedback_update', ...
    {'function [Feedback, Measure] = nf_feedback_update(Feedback, Measure, RTConfig)', ...
     '%#ok<INUSD>', ...
     'error(''test:feedback_error'', ''forced feedback update error'');', ...
     'end'});
cleanupObj = onCleanup(@() local_cleanup(tempRoot, shadowDir, cleanupShadow));

%% ===== RUN TRIAL =====
TrialResult = nf_run_live_trial(RTConfig, [], [], Baseline);

assert(TrialResult.Pass == false, 'Trial unexpectedly passed.');
assert(strcmp(TrialResult.StopReason, nf_modes().StopReason.Error), ...
    'Feedback error did not set error stop reason.');
assert(strcmp(TrialResult.ErrorIdentifier, 'test:feedback_error'), ...
    'Feedback error identifier was not preserved.');
assert(TrialResult.FeedbackClosed == true, 'Feedback cleanup was not attempted.');
assert(TrialResult.SafetyClosed == true, 'Safety cleanup was not attempted.');
assert(TrialResult.LoggerClosed == true, 'Owned logger was not closed.');
assert(TrialResult.Partial == true, 'Trial crash was not marked partial.');
assert(~isempty(TrialResult.PartialLogPaths), 'Trial crash did not save partial log.');
assert(exist(TrialResult.PartialLogPaths{end}, 'file') == 2, 'Partial log file missing.');

clear cleanupObj
end

function Baseline = local_baseline(RTConfig)
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

function [shadowDir, cleanupObj] = local_shadow_function(functionName, lines)
shadowDir = tempname();
mkdir(shadowDir);
fid = fopen(fullfile(shadowDir, [functionName '.m']), 'w');
assert(fid > 0, 'Could not create shadow function.');
for iLine = 1:numel(lines)
    fprintf(fid, '%s\n', lines{iLine});
end
fclose(fid);
addpath(shadowDir, '-begin');
clear(functionName);
cleanupObj = onCleanup(@() local_cleanup_shadow(shadowDir, functionName));
end

function local_cleanup(tempRoot, shadowDir, cleanupShadow)
clear cleanupShadow
if exist(shadowDir, 'dir')
    rmdir(shadowDir, 's');
end
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end

function local_cleanup_shadow(shadowDir, functionName)
rmpath(shadowDir);
clear(functionName);
end
