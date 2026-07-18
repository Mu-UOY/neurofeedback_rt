function test_step0_partial_report_resting_failure()
% TEST_STEP0_PARTIAL_REPORT_RESTING_FAILURE Preserve early processing failure.

Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.TestHooks.FailurePoint = ...
    Modes.DevelopmentFailure.RestingProcessing;
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
local_check(Result, Logger, Modes.DevelopmentFailure.RestingProcessing);
end

function local_check(Result, Logger, point)
assert(Result.Partial && ~Result.Pass && ~Result.ProductionEquivalent);
assert(strcmp(Result.ErrorIdentifier, ['neurofeedback:developmentInjected:' point]));
assert(exist(Result.PartialReportPath, 'file') == 2);
assert(exist(Result.PartialReportCsvPath, 'file') == 2);
assert(exist(Result.TimelinePath, 'file') == 2);
assert(Logger.Closed);
timelineText = fileread(Result.TimelinePath);
Modes = nf_modes();
assert(contains(timelineText, Modes.TimelineEvent.RestingStart));
assert(contains(timelineText, Modes.TimelineEvent.RestingManualStart));
assert(contains(timelineText, Modes.TimelineEvent.PrimaryError));
end
