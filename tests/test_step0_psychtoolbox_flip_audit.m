function test_step0_psychtoolbox_flip_audit()
% TEST_STEP0_PSYCHTOOLBOX_FLIP_AUDIT Verify signed PTB flip timing audits.

local_check_direct_signed_estimates();
local_check_session_counts_and_order();
local_check_invalid_estimates();
local_check_later_flip_validation();
end

function local_check_direct_signed_estimates()
RTConfig = nf_test_step0_config(tempname);
Feedback = nf_feedback_init(RTConfig);
fakePTB = RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox;
validValues = [-1 0 0.5 1 2];
for iValue = 1:numel(validValues)
    fakePTB.MissedValue = validValues(iValue);
    Measure = local_measure(RTConfig, iValue);
    [Feedback, ~] = nf_feedback_update(Feedback, Measure, RTConfig);
end

required = {'RequestIssuedAt','RequestedWhen','VBLTimestamp', ...
    'StimulusOnsetTime','FlipTimestamp','Missed','DeadlineMissed', ...
    'BeamPosition','MeasureTime','WindowStartSample','WindowEndSample', ...
    'ValidMeasureIndex'};
assert(Feedback.UsesHeadlessPsychtoolboxTest && ~Feedback.UsesRealPsychtoolbox);
assert(numel(Feedback.FlipAudit) == numel(validValues));
assert(all(isfield(Feedback.FlipAudit, required)));
assert(isequal([Feedback.FlipAudit.Missed], validValues));
assert(isequal([Feedback.FlipAudit.DeadlineMissed], validValues > 0));
Feedback = nf_feedback_close(Feedback);
assert(~Feedback.IsOpen);
end

function local_check_session_counts_and_order()
RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.Feedback.FlipWhen = RTConfig.ChunkSeconds;
validValues = [-1 0 0.5 1 2];
fakePTB = RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox;
fakePTB.MissedValues = validValues;
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = ...
    numel(validValues);
RTConfig.LiveTrial.TestMaxIterations = ...
    RTConfig.PowerWindowSamples ./ RTConfig.ChunkSamples + ...
    numel(validValues) + 1;

[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
audit = Result.FeedbackAudit;
assert(Result.Pass && Logger.Closed);
assert(strcmp(audit.Backend, nf_modes().FeedbackBackend.Psychtoolbox));
assert(audit.DevelopmentDisplay && audit.UsesHeadlessPsychtoolboxTest);
assert(~audit.UsesRealPsychtoolbox);
assert(audit.NFlipRequests == numel(validValues));
assert(audit.NCompletedFlips == audit.NFlipRequests);
assert(audit.NMissedFlips == nnz(validValues > 0));
assert(isequal([audit.FlipAudit.Missed], validValues));
assert(isequal([audit.FlipAudit.DeadlineMissed], validValues > 0));
assert(all([audit.FlipAudit.RequestedWhen] == ...
    RTConfig.DevelopmentSession.Feedback.FlipWhen));
assert(fakePTB.LastFlipWhen == ...
    RTConfig.DevelopmentSession.Feedback.FlipWhen);
assert(all(diff([audit.FlipAudit.VBLTimestamp]) >= 0));
assert(all(diff([audit.FlipAudit.ValidMeasureIndex]) >= 0));
assert(all(diff([audit.FlipAudit.WindowStartSample]) >= 0));
assert(all([audit.FlipAudit.WindowStartSample] >= ...
    Result.TrialResult.FirstTrialSample));
assert(all([audit.FlipAudit.WindowEndSample] <= ...
    Result.TrialResult.LastTrialSample));
assert(all([audit.FlipAudit.WindowEndSample] - ...
    [audit.FlipAudit.WindowStartSample] + 1 == RTConfig.PowerWindowSamples));
assert(all([audit.FlipAudit.ValidMeasureIndex] <= ...
    Result.TrialResult.NValidMeasures));
assert(ismember(audit.ScreenNumber, audit.AvailableScreens));
assert(numel(audit.WindowRect) == 4 && all(isfinite(audit.WindowRect)));
assert(all(isfinite([audit.LatencyMeanMs, audit.LatencyMedianMs, ...
    audit.LatencyConfiguredPercentileMs, audit.LatencyP95Ms, ...
    audit.LatencyMaxMs])));
end

function local_check_invalid_estimates()
invalidValues = {NaN, Inf, -Inf, 1 + 1i, [0 1], true, ...
    string('bad'), 'bad', {0}, struct('Value', 0)};
for iValue = 1:numel(invalidValues)
    RTConfig = nf_test_step0_config(tempname);
    Feedback = nf_feedback_init(RTConfig);
    RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox.MissedValue = ...
        invalidValues{iValue};
    didError = false;
    try
        nf_feedback_update(Feedback, local_measure(RTConfig, 1), RTConfig);
    catch ME
        didError = true;
        assert(strcmp(ME.identifier, ...
            'neurofeedback:developmentFeedbackAuditInvalid'));
        assert(contains(lower(ME.message), 'missed deadline estimate'));
    end
    Feedback = nf_feedback_close(Feedback);
    assert(didError);
end

RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox.MissedValue = NaN;
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
assert(Result.Partial && ~Result.Pass && Logger.Closed);
assert(strcmp(Result.ErrorIdentifier, ...
    'neurofeedback:developmentFeedbackAuditInvalid'));
assert(contains(lower(Result.ErrorReport), 'missed deadline estimate'));
end

function local_check_later_flip_validation()
RTConfig = nf_test_step0_config(tempname);
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = ...
    RTConfig.Feedback.UpdateEveryNValidMeasures + 1;
RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox.MalformedFlipIndex = ...
    RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates;
[malformed, ~, ~, malformedLogger] = ...
    nf_run_development_full_chain(RTConfig);
assert(malformed.Partial && ~malformed.Pass && malformedLogger.Closed);
assert(strcmp(malformed.ErrorIdentifier, ...
    'neurofeedback:developmentFeedbackAuditInvalid'));

orderConfig = nf_test_step0_config(tempname);
orderConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = ...
    orderConfig.Feedback.UpdateEveryNValidMeasures + 1;
orderConfig.DevelopmentSession.TestHooks.FakePsychtoolbox.TimestampValues = ...
    [orderConfig.ChunkSeconds, 0];
[unordered, ~, ~, unorderedLogger] = ...
    nf_run_development_full_chain(orderConfig);
assert(unordered.Partial && ~unordered.Pass && unorderedLogger.Closed);
assert(strcmp(unordered.ErrorIdentifier, ...
    'neurofeedback:developmentFeedbackAuditInvalid'));
assert(contains(lower(unordered.ErrorReport), 'nondecreasing'));
end

function Measure = local_measure(RTConfig, validIndex)
Measure = nf_measure_empty();
Measure.Time = validIndex .* RTConfig.ChunkSeconds;
Measure.WindowStartSample = 1 + ...
    (validIndex - 1) .* RTConfig.ChunkSamples;
Measure.WindowEndSample = Measure.WindowStartSample + ...
    RTConfig.PowerWindowSamples - 1;
Measure.ValidMeasureIndex = validIndex;
Measure.FeedbackTargetRadiusPx = RTConfig.Feedback.Circle.MinRadiusPx;
Measure.FeedbackDisplayRadiusPx = RTConfig.Feedback.Circle.MinRadiusPx;
Measure.FeedbackOuterRadiusPx = RTConfig.Feedback.Circle.MaxRadiusPx;
Measure.FeedbackDisplayType = nf_modes().FeedbackDisplay.Circle;
end
