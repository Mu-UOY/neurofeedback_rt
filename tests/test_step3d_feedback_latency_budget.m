function test_step3d_feedback_latency_budget()
% TEST_STEP3D_FEEDBACK_LATENCY_BUDGET Check latency metrics and fail switch.

[RTConfig, tempRoot] = nf_test_live_self_test_config();
cleanupObj = onCleanup(@() local_cleanup(tempRoot));
RTConfig.Feedback.LatencyBudgetMs = 0;
RTConfig.Feedback.WarnOnLatencyBudgetExceeded = true;
RTConfig.Feedback.FailOnLatencyBudgetExceeded = false;
RTConfig.Feedback.MaxConsecutiveLatencyWarnings = 1;

Result = nf_run_live_self_test(RTConfig);
assert(Result.TrialResult.NFeedbackLatencyWarnings >= 1, 'Latency warnings were not counted.');
assert(isfinite(Result.TrialResult.FeedbackLatencyMsMax), 'Latency max was not measured.');
assert(Result.Pass == true, 'Warn-only latency budget should not fail self-test.');

RTConfig.Feedback.FailOnLatencyBudgetExceeded = true;
Result2 = nf_run_live_self_test(RTConfig);
assert(Result2.TrialResult.NFeedbackLatencyWarnings >= 1, 'Failing latency warnings were not counted.');
assert(Result2.TrialResult.Pass == false, 'Fail-on-latency did not fail trial.');

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
