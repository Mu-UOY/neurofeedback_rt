function test_step0_feedback_audit_bounds()
% TEST_STEP0_FEEDBACK_AUDIT_BOUNDS Reject impossible later flip metadata.

RTConfig = nf_test_step0_config(tempname);
nRequiredFlips = 2;
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = ...
    nRequiredFlips .* RTConfig.Feedback.UpdateEveryNValidMeasures;
RTConfig.LiveTrial.TestMaxIterations = ...
    RTConfig.PowerWindowSamples ./ RTConfig.ChunkSamples + ...
    RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates + 1;
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
assert(Result.Pass && Logger.Closed);
Audit = Result.FeedbackAudit;
Trial = Result.TrialResult;
Modes = nf_modes();
assert(numel(Audit.FlipAudit) >= 2, ...
    'The bounds test requires a later feedback flip.');
nf_validate_development_feedback_audit(Audit, Trial, RTConfig, Modes);

iFlip = 2;
bad = Audit;
bad.FlipAudit(iFlip).ValidMeasureIndex = Trial.NValidMeasures + 1;
local_expect_invalid(bad, Trial, RTConfig, Modes, 'measure index');

bad = Audit;
bad.FlipAudit(iFlip).WindowEndSample = ...
    bad.FlipAudit(iFlip).WindowEndSample + 1;
local_expect_invalid(bad, Trial, RTConfig, Modes, 'window length');

bad = Audit;
bad.FlipAudit(iFlip).WindowEndSample = Trial.LastTrialSample + 1;
bad.FlipAudit(iFlip).WindowStartSample = ...
    bad.FlipAudit(iFlip).WindowEndSample - RTConfig.PowerWindowSamples + 1;
local_expect_invalid(bad, Trial, RTConfig, Modes, 'final processed trial sample');

bad = Audit;
bad.FlipAudit(iFlip).WindowStartSample = Trial.FirstTrialSample - 1;
bad.FlipAudit(iFlip).WindowEndSample = ...
    bad.FlipAudit(iFlip).WindowStartSample + RTConfig.PowerWindowSamples - 1;
local_expect_invalid(bad, Trial, RTConfig, Modes, 'transition or pre-warm-up');

badTrial = Trial;
badTrial.LastTrialSample = badTrial.FirstValidMeasureWindowEndSample - 1;
local_expect_invalid(Audit, badTrial, RTConfig, Modes, 'trial bounds');
end

function local_expect_invalid(Audit, Trial, RTConfig, Modes, messageToken)
didError = false;
try
    nf_validate_development_feedback_audit(Audit, Trial, RTConfig, Modes);
catch ME
    didError = true;
    assert(strcmp(ME.identifier, ...
        'neurofeedback:developmentFeedbackAuditInvalid'));
    assert(contains(lower(ME.message), lower(messageToken)), ...
        'Unexpected feedback-audit error: %s', ME.message);
end
assert(didError, 'Malformed feedback audit was accepted.');
end
