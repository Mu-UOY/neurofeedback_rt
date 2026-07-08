function test_live_rt_dry_run_calls_rt_core_but_not_feedback()
% TEST_LIVE_RT_DRY_RUN_CALLS_RT_CORE_BUT_NOT_FEEDBACK Check static and runtime scope.

rootDir = fileparts(fileparts(mfilename('fullpath')));
txt = fileread(fullfile(rootDir, 'main', 'nf_run_live_rt_dry_run.m'));

required = {'nf_rt_prepare','nf_rt_process_chunk','nf_source_init','nf_get_meg_chunk'};
for iName = 1:numel(required)
    assert(contains(txt, required{iName}), 'Runner missing required call: %s', required{iName});
end

forbidden = {'nf_feedback_init','nf_feedback_update','nf_feedback_close', ...
    'nf_feedback_map_to_display','nf_feedback_circle_radius', ...
    'nf_baseline_init','nf_baseline_update','nf_baseline_finalize', ...
    'nf_load_baseline','nf_run_live_resting','nf_run_live_trial', ...
    'nf_run_live_self_test'};
for iName = 1:numel(forbidden)
    assert(~contains(txt, forbidden{iName}), 'Runner contains forbidden name: %s', forbidden{iName});
end

[RTConfig, tempRoot] = nf_test_live_rt_dry_run_config(35);
cleanupObj = onCleanup(@() local_cleanup(tempRoot));
Result = nf_run_live_rt_dry_run(RTConfig);
assert(Result.Pass == true, 'Runtime dry run failed.');
assert(Result.FeedbackUnmappedPass == true, 'Feedback fields were mapped.');
clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
