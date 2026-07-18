function test_step0_fresh_trial_state()
% TEST_STEP0_FRESH_TRIAL_STATE Verify positive and zero full-chain backlog.

local_run_case(true);
local_run_case(false);
end

function local_run_case(hasBacklog)
RTConfig = nf_test_step0_config(tempname);
if ~hasBacklog
    outputRoot = RTConfig.Paths.ProjectRoot;
    RTConfig.DevelopmentSession.Transition.TestAdvanceChunks = 0;
    RTConfig = nf_finalize_config(RTConfig);
    RTConfig.Paths.ProjectRoot = outputRoot;
    RTConfig.Source.FieldTrip.TestBufferFcn = ...
        nf_make_development_fieldtrip_buffer(RTConfig);
end
[Result, ~, ~, Logger] = nf_run_development_full_chain(RTConfig);
Trial = Result.TrialResult;
Transition = Result.TransitionResult;
assert(Result.Pass && Transition.RangeKnown);
if hasBacklog
    expectedSkipped = RTConfig.DevelopmentSession.Transition.TestAdvanceSamples;
    assert(~Transition.NoSamplesSkipped);
    assert(Transition.SkippedSampleCount == expectedSkipped);
    assert(Transition.SkippedFirstSample == Transition.PreviousSample + 1);
    assert(Transition.SkippedLastSample == Transition.LatestSample);
    assert(Transition.SkippedSampleCount == ...
        Transition.SkippedLastSample - Transition.SkippedFirstSample + 1);
    assert(Trial.FirstTrialSample == Transition.SkippedLastSample + 1);
else
    assert(Transition.NoSamplesSkipped && Transition.SkippedSampleCount == 0);
    assert(isnan(Transition.SkippedFirstSample));
    assert(isnan(Transition.SkippedLastSample));
    assert(Trial.FirstTrialSample == Transition.PreviousSample + 1);
end
assert(Trial.FirstValidMeasureWindowEndSample >= ...
    Trial.FirstTrialSample + RTConfig.PowerWindowSamples - 1);
assert(Trial.LastTrialSample >= Trial.FirstValidMeasureWindowEndSample);
assert(Trial.FirstFeedbackUpdateWindowEndSample >= ...
    Trial.FirstValidMeasureWindowEndSample);
assert(Trial.FirstFeedbackUpdateWindowEndSample <= Trial.LastTrialSample);

trialChunks = Logger.ChunkMeta(strcmp({Logger.ChunkMeta.Phase}, ...
    nf_modes().Session.LiveTrial));
assert(~isempty(trialChunks));
assert(all([trialChunks.StartSample] >= Trial.FirstTrialSample));
trialMeasures = Logger.Measures((Result.RestingResult.NChunks + 1):end);
assert(numel(trialMeasures) == Trial.NChunks);
sampleFields = {'WindowStartSample','WindowCenterSample', ...
    'WindowEndSample','CorrectedWindowStartSample', ...
    'CorrectedWindowCenterSample','CorrectedWindowEndSample'};
for iField = 1:numel(sampleFields)
    values = [trialMeasures.(sampleFields{iField})];
    assert(all(values(isfinite(values)) >= Trial.FirstTrialSample));
end
flips = Result.FeedbackAudit.FlipAudit;
assert(all([flips.WindowStartSample] >= Trial.FirstTrialSample));
assert(all([flips.WindowEndSample] <= Trial.LastTrialSample));
assert(all([flips.WindowEndSample] - [flips.WindowStartSample] + 1 == ...
    RTConfig.PowerWindowSamples));
assert(all([flips.ValidMeasureIndex] <= Trial.NValidMeasures));
end
