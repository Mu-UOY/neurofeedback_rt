function test_live_rt_dry_run_feedback_fields_remain_unmapped()
% TEST_LIVE_RT_DRY_RUN_FEEDBACK_FIELDS_REMAIN_UNMAPPED Check display fields.

[RTConfig, tempRoot] = nf_test_live_rt_dry_run_config(35);
cleanupObj = onCleanup(@() local_cleanup(tempRoot));
Result = nf_run_live_rt_dry_run(RTConfig);
loaded = load(Result.ReportMatPath, 'Measures');
Measures = loaded.Measures;

assert(Result.FeedbackUnmappedPass == true, 'Result feedback-unmapped check failed.');
assert(~isempty(Measures), 'No measures were saved.');
for iMeasure = 1:numel(Measures)
    Measure = Measures(iMeasure);
    assert(isnan(Measure.FeedbackValue), 'FeedbackValue was assigned.');
    assert(isnan(Measure.FeedbackTargetRadiusPx), 'FeedbackTargetRadiusPx was assigned.');
    assert(isnan(Measure.FeedbackDisplayRadiusPx), 'FeedbackDisplayRadiusPx was assigned.');
    assert(isnan(Measure.FeedbackOuterRadiusPx), 'FeedbackOuterRadiusPx was assigned.');
    assert(isempty(Measure.FeedbackDisplayType), 'FeedbackDisplayType was assigned.');
    assert(isnan(Measure.FeedbackDisplayTime), 'FeedbackDisplayTime was assigned.');
end

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
