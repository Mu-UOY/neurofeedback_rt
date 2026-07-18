function test_step0_logger_failure_cleanup()
% TEST_STEP0_LOGGER_FAILURE_CLEANUP Cover append and first-close failures.

Modes = nf_modes();
local_run_case(Modes.DevelopmentFailure.LoggerAppend, true);
local_run_case(Modes.DevelopmentFailure.LoggerClose, false);
end

function local_run_case(failurePoint, expectCheckpoint)
Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.TestHooks.FailurePoint = failurePoint;
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
expectedID = ['neurofeedback:developmentInjected:' failurePoint];
assert(Result.Partial && ~Result.Pass && Logger.Closed && Result.LoggerClosed);
assert(strcmp(Result.ErrorIdentifier, expectedID));
assert(contains(Result.Error, failurePoint));
assert(contains(Result.ErrorReport, failurePoint));
assert(exist(Result.PartialReportPath, 'file') == 2);
assert(exist(Result.PartialReportCsvPath, 'file') == 2);
assert(exist(Result.TimelinePath, 'file') == 2);
if expectCheckpoint
    assert(~isempty(Logger.PartialLogPaths));
    assert(any(cellfun(@(p) exist(p, 'file') == 2, Logger.PartialLogPaths)));
    timelineText = fileread(Result.TimelinePath);
    assert(contains(timelineText, Modes.TimelineEvent.RestingFirstChunk));
else
    assert(isempty(Result.CleanupMessages));
end
end
