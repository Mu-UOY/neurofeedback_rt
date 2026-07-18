function test_step0_partial_report_trial_failure()
% TEST_STEP0_PARTIAL_REPORT_TRIAL_FAILURE Preserve trial RT failure identity.

Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.TestHooks.FailurePoint = ...
    Modes.DevelopmentFailure.TrialProcessing;
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
assert(Result.Partial && ~Result.Pass);
assert(strcmp(Result.ErrorIdentifier, ...
    ['neurofeedback:developmentInjected:' Modes.DevelopmentFailure.TrialProcessing]));
assert(exist(Result.PartialReportPath, 'file') == 2 && Logger.Closed);
timelineText = fileread(Result.TimelinePath);
assert(contains(timelineText, Modes.TimelineEvent.TrialStart));
assert(contains(timelineText, Modes.TimelineEvent.FeedbackInitialized));
assert(contains(timelineText, Modes.TimelineEvent.TrialStop));
end
