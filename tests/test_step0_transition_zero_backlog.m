function test_step0_transition_zero_backlog()
% TEST_STEP0_TRANSITION_ZERO_BACKLOG Distinguish known zero from unknown.

RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.Transition.TestAdvanceChunks = 0;
RTConfig = nf_finalize_config(RTConfig);
RTConfig.Source.FieldTrip.TestBufferFcn = nf_make_development_fieldtrip_buffer(RTConfig);
Modes = nf_modes();
Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
[Source, ~] = nf_source_resync_after_pause(Source, RTConfig, Modes.Phase.Resting);
sessionDir = tempname; mkdir(sessionDir);
Timeline = nf_development_timeline_init(RTConfig, sessionDir);
[Result, ~] = nf_run_development_transition(RTConfig, Source, Timeline);
assert(Result.Pass && Result.RangeKnown && Result.NoSamplesSkipped);
assert(Result.SkippedSampleCount == 0);
assert(isnan(Result.SkippedFirstSample) && isnan(Result.SkippedLastSample));
end
