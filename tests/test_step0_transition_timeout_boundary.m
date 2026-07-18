function test_step0_transition_timeout_boundary()
% TEST_STEP0_TRANSITION_TIMEOUT_BOUNDARY Enforce strict greater-than timeout.

Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
maximum = RTConfig.DevelopmentSession.Transition.MaxPauseSeconds;
delta = RTConfig.DevelopmentSession.Transition.TimeoutBoundaryDeltaSeconds;
RTConfig.Protocol.ManualStartMaxWaitSeconds = maximum;
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = maximum;
allowed = nf_wait_for_manual_start(RTConfig, Modes.Phase.Transition);
assert(~allowed.TimedOut);
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = maximum + delta;
timedOut = nf_wait_for_manual_start(RTConfig, Modes.Phase.Transition);
assert(timedOut.TimedOut);
assert(strcmp(timedOut.StopReason, Modes.StopReason.TransitionTimeout));

RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = maximum;
Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
sessionDir = tempname; mkdir(sessionDir);
Timeline = nf_development_timeline_init(RTConfig, sessionDir);
[atBoundary, Source, Timeline] = ...
    nf_run_development_transition(RTConfig, Source, Timeline);
assert(atBoundary.Pass && ~atBoundary.TimedOut);

RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = maximum + delta;
[overrun, ~] = nf_run_development_transition(RTConfig, Source, Timeline);
assert(~overrun.Pass && overrun.TimedOut);
assert(strcmp(overrun.StopReason, Modes.StopReason.TransitionTimeout));

%% ===== FULL CHAIN STOPS BEFORE TRIAL =====
fullConfig = nf_test_step0_config(tempname);
fullConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = ...
    fullConfig.DevelopmentSession.Transition.MaxPauseSeconds + ...
    fullConfig.DevelopmentSession.Transition.TimeoutBoundaryDeltaSeconds;
[fullResult, ~, ~, fullLogger] = nf_run_development_full_chain(fullConfig);
assert(fullResult.Partial && ~fullResult.Pass && fullLogger.Closed);
assert(fullResult.LoggerClosed);
assert(strcmp(fullResult.StopReason, Modes.StopReason.TransitionTimeout));
assert(strcmp(fullResult.ErrorIdentifier, ...
    'neurofeedback:developmentTransitionTimeout'));
assert(isempty(fieldnames(fullResult.TrialResult)));
assert(isempty(fieldnames(fullResult.FeedbackAudit)));
assert(exist(fullResult.PartialReportPath, 'file') == 2);
assert(exist(fullResult.PartialReportCsvPath, 'file') == 2);
assert(exist(fullResult.TimelinePath, 'file') == 2);
timelineText = fileread(fullResult.TimelinePath);
assert(contains(timelineText, Modes.TimelineEvent.TransitionTimeout));
assert(~contains(timelineText, Modes.TimelineEvent.TrialStart));
assert(~contains(timelineText, Modes.TimelineEvent.FeedbackInitialized));
assert(~contains(timelineText, Modes.TimelineEvent.FeedbackFlip));
end
