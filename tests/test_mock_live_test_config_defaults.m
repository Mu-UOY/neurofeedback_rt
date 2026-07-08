function test_mock_live_test_config_defaults()
% TEST_MOCK_LIVE_TEST_CONFIG_DEFAULTS Check finalized mock-live defaults.

%% ===== CHECK MOCK-LIVE DEFAULTS =====
% This config is hardware-free and uses technical fallback only as config.
Modes = nf_modes();
RTConfig = nf_mock_live_test_config();

assert(RTConfig.Internal.IsFinalized == true, 'Mock-live config must be finalized.');
assert(strcmp(RTConfig.Source.Mode, Modes.Source.MockLiveBuffer));
assert(strcmp(RTConfig.Source.LiveAdapter, Modes.LiveAdapter.MockBuffer));
assert(RTConfig.Feedback.RequirePsychtoolboxForLive == false);
assert(RTConfig.Feedback.AllowDebugPlotFallback == true);
assert(strcmp(RTConfig.Spatial.Mode, Modes.Spatial.CombinedMatrix));
assert(strcmp(RTConfig.Spatial.MatrixSource, Modes.Spatial.MatrixSource.TechnicalFallback));
assert(RTConfig.Source.CTF.ApplyChannelGains == false);
assert(RTConfig.Source.CTF.ApplyMegRefCorrection == false);
assert(RTConfig.Source.CTF.ApplyProjector == false);
assert(RTConfig.Source.FieldTrip.RequireCTFRes4 == false);

end
