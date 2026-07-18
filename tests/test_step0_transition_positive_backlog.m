function test_step0_transition_positive_backlog()
% TEST_STEP0_TRANSITION_POSITIVE_BACKLOG Verify exact inclusive discard range.

RTConfig = nf_test_step0_config(tempname);
Modes = nf_modes();
Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
[Source, ~] = nf_source_resync_after_pause(Source, RTConfig, Modes.Phase.Resting);
sessionDir = tempname; mkdir(sessionDir);
Timeline = nf_development_timeline_init(RTConfig, sessionDir);
[Result, ~] = nf_run_development_transition(RTConfig, Source, Timeline);
assert(Result.Pass && Result.RangeKnown && ~Result.NoSamplesSkipped);
assert(Result.SkippedSampleCount == ...
    RTConfig.DevelopmentSession.Transition.TestAdvanceSamples);
assert(Result.SkippedSampleCount == ...
    Result.SkippedLastSample - Result.SkippedFirstSample + 1);
end
