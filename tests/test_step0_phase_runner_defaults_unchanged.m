function test_step0_phase_runner_defaults_unchanged()
% TEST_STEP0_PHASE_RUNNER_DEFAULTS_UNCHANGED Preserve existing caller behavior.

RTConfig = nf_live_config();
Modes = nf_modes();
assert(strcmp(RTConfig.PhaseRunner.ManualStartOwner, Modes.PhaseRunnerOwner.Internal));
assert(strcmp(RTConfig.PhaseRunner.ResyncOwner, Modes.PhaseRunnerOwner.Internal));
assert(~RTConfig.DevelopmentSession.Enabled);

RTConfig = nf_test_step0_config(tempname);
delta = RTConfig.DevelopmentSession.Transition.TimeoutBoundaryDeltaSeconds;
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Resting = delta;
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = 2 .* delta;
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Trial = 3 .* delta;
RTConfig.Session.Mode = Modes.Session.DevelopmentFullChain;
resting = nf_wait_for_manual_start(RTConfig, Modes.Session.LiveResting);
transition = nf_wait_for_manual_start(RTConfig, Modes.Phase.Transition);
trial = nf_wait_for_manual_start(RTConfig, Modes.Session.LiveTrial);
assert(resting.WaitDurationSeconds == delta);
assert(transition.WaitDurationSeconds == 2 .* delta);
assert(trial.WaitDurationSeconds == 3 .* delta);
didError = false;
try
    nf_wait_for_manual_start(RTConfig, 'unknown_step0_phase');
catch ME
    didError = contains(ME.message, 'Unknown Step 0 manual-start phase');
end
assert(didError);
end
