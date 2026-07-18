function test_step3d_stop_and_success_helpers()
% TEST_STEP3D_STOP_AND_SUCCESS_HELPERS Check priority and consecutive success.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Protocol.Trial.Success.Enabled = true;
RTConfig.Protocol.Trial.Success.SourceField = 'ZSmoothed';
RTConfig.Protocol.Trial.Success.Threshold = 1;
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = 2;

Safety = struct('StopRequested', true);
TrialState = struct('SuccessMet', true);
LoopState = local_loop_state();
LoopState.TimeoutLimitExceeded = true;
Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState);
assert(strcmp(Stop.Reason, Modes.StopReason.Timeout), 'Timeout did not outrank manual/success.');

Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.ZSmoothed = 1.2;
TrialState = struct();
[successMet, TrialState] = nf_trial_success_criterion_met(Measure, TrialState, RTConfig);
assert(successMet == false, 'Success triggered too early.');
[successMet, TrialState] = nf_trial_success_criterion_met(Measure, TrialState, RTConfig);
assert(successMet == true && TrialState.SuccessMet == true, 'Consecutive success did not trigger.');

Measure.ZSmoothed = 0;
[successMet, TrialState] = nf_trial_success_criterion_met(Measure, TrialState, RTConfig);
assert(successMet == false, 'Success did not reset below threshold.');
assert(TrialState.SuccessConsecutiveCount == 0, 'Consecutive count did not reset.');
end

function LoopState = local_loop_state()
LoopState = struct();
LoopState.ErrorOccurred = false;
LoopState.HardFailsafeExceeded = false;
LoopState.TimeoutLimitExceeded = false;
LoopState.ManualStopRequested = false;
LoopState.FixedDurationCompleted = false;
LoopState.LastError = '';
end
