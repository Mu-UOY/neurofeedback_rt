function test_step0_development_full_chain_success()
% TEST_STEP0_DEVELOPMENT_FULL_CHAIN_SUCCESS Exercise the complete happy path.

RTConfig = nf_test_step0_config(tempname);
[Result, ~, Spatial, Logger] = nf_run_development_full_chain(RTConfig);
Modes = nf_modes();
assert(Result.Pass && Result.Completed && ~Result.Partial);
assert(strcmp(Result.OverallStatus, Modes.DevelopmentStatus.Pass));
assert(Result.DevelopmentOnly && ~Result.ProductionEquivalent);
assert(Spatial.IsTechnicalFallback && ~Spatial.IsIPS);
assert(Result.SpatialSummary.SameHashAcrossPhases);
assert(strcmp(Result.RestingResult.SpatialHash, Spatial.Hash));
assert(strcmp(Result.TrialResult.SpatialHash, Spatial.Hash));
assert(isequal(Result.RestingResult.SpatialSize, size(Spatial.CombinedMatrix)));
assert(isequal(Result.TrialResult.SpatialSize, size(Spatial.CombinedMatrix)));
assert(Result.SourceReady && Result.SourceSummary.ReadinessPass);
assert(Result.SourceSummary.AdvancementCount == ...
    RTConfig.DevelopmentSession.Source.ReadinessAdvanceSamples);
audit = Result.FeedbackAudit;
assert(strcmp(audit.Backend, Modes.FeedbackBackend.Psychtoolbox));
assert(audit.DevelopmentDisplay && audit.UsesHeadlessPsychtoolboxTest);
assert(~audit.UsesRealPsychtoolbox && audit.NCompletedFlips >= 1);
assert(audit.NCompletedFlips <= audit.NFlipRequests);
assert(audit.NCompletedFlips == audit.NFlipRequests);
assert(audit.NMissedFlips == nnz([audit.FlipAudit.Missed] > 0));
assert(all([audit.FlipAudit.DeadlineMissed] == ...
    ([audit.FlipAudit.Missed] > 0)));
assert(all(isfinite([audit.FlipAudit(1).VBLTimestamp, ...
    audit.FlipAudit(1).StimulusOnsetTime, audit.FlipAudit(1).FlipTimestamp])));
assert(Logger.Closed);
assert(strcmp(Result.StopReason, Modes.StopReason.Success));
assert(Result.BaselineReloaded && ~isempty(Result.BaselineConfigHash));
assert(strcmp(Result.BaselineConfigHash, Result.TrialBaselineConfigHash));
assert(strcmp(Result.BaselineConfigHash, ...
    Result.TrialResult.BaselineConfigHash));
assert(exist(Result.SummaryPath, 'file') == 2);
assert(exist(Result.SummaryCsvPath, 'file') == 2);
assert(exist(Result.TimelinePath, 'file') == 2);
end
