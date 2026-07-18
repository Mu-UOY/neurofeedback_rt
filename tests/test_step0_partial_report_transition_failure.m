function test_step0_partial_report_transition_failure()
% TEST_STEP0_PARTIAL_REPORT_TRANSITION_FAILURE Save audit before trial entry.

Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.TestHooks.FailurePoint = Modes.DevelopmentFailure.Transition;
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
assert(Result.Partial && isempty(fieldnames(Result.TrialResult)));
assert(strcmp(Result.ErrorIdentifier, ...
    ['neurofeedback:developmentInjected:' Modes.DevelopmentFailure.Transition]));
assert(exist(Result.PartialReportPath, 'file') == 2 && Logger.Closed);
timelineText = fileread(Result.TimelinePath);
assert(contains(timelineText, Modes.TimelineEvent.TransitionWaitStart));
assert(contains(timelineText, Modes.TimelineEvent.TransitionWaitEnd));
assert(~contains(timelineText, Modes.TimelineEvent.TrialStart));
end
