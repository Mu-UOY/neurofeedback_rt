function test_live_config_defaults()
% TEST_LIVE_CONFIG_DEFAULTS Check raw Step 3 live config defaults.

%% ===== CHECK LIVE DEFAULTS =====
% nf_live_config is intentionally raw: RequireCTFRes4 is finalized later.
Modes = nf_modes();
RTConfig = nf_live_config();

assert(RTConfig.Internal.IsFinalized == false, 'Live config should be raw.');
assert(strcmp(RTConfig.Source.Mode, Modes.Source.LiveFieldTrip));
assert(strcmp(RTConfig.Source.LiveAdapter, Modes.LiveAdapter.BenFieldTrip));
assert(RTConfig.Fs == 2400);
assert(RTConfig.ChunkSeconds == 0.2);
assert(RTConfig.ChunkSamples == 480);
assert(RTConfig.PowerWindowSeconds == 2.0);
assert(RTConfig.PowerWindowSamples == 4800);
assert(RTConfig.BufferSamples == 4800);
assert(strcmp(RTConfig.Filter.Type, Modes.Filter.IIRSOS));
assert(strcmp(RTConfig.Spatial.Mode, Modes.Spatial.CombinedMatrix));
assert(strcmp(RTConfig.Spatial.MatrixSource, Modes.Spatial.MatrixSource.Precomputed));
assert(RTConfig.Protocol.Trial.MaxFailsafeSeconds == 30 * 60);
assert(isempty(RTConfig.Source.FieldTrip.RequireCTFRes4));
assert(RTConfig.Feedback.Circle.VisualAlpha == 1.0);

end
