function test_step3d_live_self_test_fake_buffer_passes()
% TEST_STEP3D_LIVE_SELF_TEST_FAKE_BUFFER_PASSES Run full hardware-free self-test.

[RTConfig, tempRoot] = nf_test_live_self_test_config();
cleanupObj = onCleanup(@() local_cleanup(tempRoot));

Result = nf_run_live_self_test(RTConfig);

assert(Result.Pass == true, 'Live self-test failed: %s', Result.Recommendation);
assert(Result.RestingResult.Pass == true, 'Resting phase failed.');
assert(exist(Result.BaselinePath, 'file') == 2, 'Baseline file was not saved.');
assert(Result.TrialResult.Started == true, 'Trial did not start.');
assert(Result.TrialResult.Pass == true, 'Trial phase failed.');
assert(Result.TrialResult.NFiniteZSmoothed >= 1, 'Trial did not produce finite ZSmoothed.');
assert(Result.TrialResult.NFeedbackUpdates >= 1, 'Feedback did not update.');
assert(Result.FeedbackClosed == true, 'Feedback was not closed.');
assert(Result.LoggerClosed == true, 'Logger was not closed.');
assert(Result.SpatialSummary.IsTechnicalFallback == true, 'Technical fallback flag missing.');
assert(Result.SpatialSummary.IsIPS == false, 'Technical fallback claimed IPS.');
assert(exist(Result.ReportMatPath, 'file') == 2, 'Audit MAT missing.');
assert(exist(Result.ReportTextPath, 'file') == 2, 'Audit text missing.');
assert(exist(Result.ConfigPath, 'file') == 2, 'Audit config missing.');
assert(exist(Result.SummaryCsvPath, 'file') == 2, 'Audit CSV missing.');

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
