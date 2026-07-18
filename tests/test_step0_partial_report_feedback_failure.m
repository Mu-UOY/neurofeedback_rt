function test_step0_partial_report_feedback_failure()
% TEST_STEP0_PARTIAL_REPORT_FEEDBACK_FAILURE Preserve primary display error.

Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.TestHooks.FailurePoint = ...
    Modes.DevelopmentFailure.FeedbackUpdate;
RTConfig.DevelopmentSession.TestHooks.SafetyShutdownFcn = ...
    @local_fail_safety_cleanup;
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);

expectedID = ['neurofeedback:developmentInjected:' ...
    Modes.DevelopmentFailure.FeedbackUpdate];
assert(Result.Partial && ~Result.Pass);
assert(strcmp(Result.ErrorIdentifier, expectedID));
assert(contains(Result.ErrorReport, Modes.DevelopmentFailure.FeedbackUpdate));
assert(~isempty(Result.TrialResult.CleanupMessages));
assert(any(contains(Result.TrialResult.CleanupMessages, ...
    'Injected Step 0 safety cleanup failure.')));
assert(Logger.Closed && Result.LoggerClosed);
assert(exist(Result.PartialReportPath, 'file') == 2);
assert(exist(Result.PartialReportCsvPath, 'file') == 2);
assert(exist(Result.TimelinePath, 'file') == 2);

timelineText = fileread(Result.TimelinePath);
assert(contains(timelineText, Modes.TimelineEvent.TrialFirstValidMeasure));
assert(~contains(timelineText, Modes.TimelineEvent.FeedbackFlip));
assert(contains(timelineText, Modes.TimelineEvent.CleanupError));
assert(contains(timelineText, Modes.TimelineEvent.PrimaryError));

freshConfig = nf_test_step0_config(tempname);
assert(isempty(freshConfig.DevelopmentSession.TestHooks.SafetyShutdownFcn));
assert(isempty(freshConfig.DevelopmentSession.TestHooks.PauseFcn));
end

function local_fail_safety_cleanup(varargin) %#ok<INUSD>
error('neurofeedback:developmentInjected:safety_cleanup', ...
    'Injected Step 0 safety cleanup failure.');
end
