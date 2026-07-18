function test_step0_source_readiness_advancement()
% TEST_STEP0_SOURCE_READINESS_ADVANCEMENT Require deterministic evidence.

RTConfig = nf_test_step0_config(tempname);
Modes = nf_modes();
assert(RTConfig.DevelopmentSession.Enabled);
assert(strcmp(RTConfig.DevelopmentSession.DisplayMode, ...
    Modes.DevelopmentDisplay.HeadlessPsychtoolboxTest));
assert(RTConfig.DevelopmentSession.TestHooks.Enabled);
assert(isa(RTConfig.Source.FieldTrip.TestBufferFcn, 'function_handle'));
assert(strcmp(RTConfig.Source.FieldTrip.StreamRole, Modes.StreamRole.TestHook));
assert(isa(RTConfig.DevelopmentSession.TestHooks.ScreenFcn, 'function_handle'));
assert(isa(RTConfig.DevelopmentSession.TestHooks.TimeFcn, 'function_handle'));
assert(~RTConfig.Session.ProductionEquivalent);
[Result, Source] = nf_run_development_full_chain(RTConfig);
summary = Result.SourceSummary;
assert(Result.Pass && Result.SourceReady && summary.ReadinessPass);
assert(strcmp(summary.ReadinessStatus, Modes.ReadinessStatus.Pass));
assert(summary.LaterNSamples > summary.InitialNSamples);
assert(summary.AdvancementCount == ...
    RTConfig.DevelopmentSession.Source.ReadinessAdvanceSamples);
assert(Source.LastSampleRead > summary.LaterNSamples);
end
