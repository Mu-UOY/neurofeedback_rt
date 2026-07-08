function test_check_config_live_fields_without_acquisition()
% TEST_CHECK_CONFIG_LIVE_FIELDS_WITHOUT_ACQUISITION Check config-only validation.

%% ===== CHECK RAW LIVE CONFIG =====
% nf_check_config must not start source initialization or live buffer reads.
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
nf_check_config(RTConfig);

%% ===== CHECK FINALIZED ACQUISITION-ONLY CONFIG =====
% Finalization validates fields without touching FieldTrip, Brainstorm, or buffer().
RTConfig.Session.Mode = Modes.Session.LiveDiagnostics;
RTConfig = nf_finalize_config(RTConfig);
assert(RTConfig.Internal.IsFinalized == true, 'Config was not finalized.');
assert(RTConfig.Source.FieldTrip.RequireCTFRes4 == false, ...
    'Acquisition-only finalization forced CTF res4.');

end
