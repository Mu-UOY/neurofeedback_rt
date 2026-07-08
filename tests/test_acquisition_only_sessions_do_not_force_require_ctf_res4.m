function test_acquisition_only_sessions_do_not_force_require_ctf_res4()
% TEST_ACQUISITION_ONLY_SESSIONS_DO_NOT_FORCE_REQUIRE_CTF_RES4 Check CTF scope.

%% ===== CHECK CTF RES4 DERIVATION =====
% Live CTF correction defaults must not force metadata for acquisition-only checks.
Modes = nf_modes();
acquisitionOnly = { ...
    Modes.Session.LiveDiagnostics, ...
    Modes.Session.LiveChannelCheck, ...
    Modes.Session.LiveChunkSmokeTest};

for iMode = 1:numel(acquisitionOnly)
    RTConfig = nf_live_config();
    RTConfig.Debug.Verbose = false;
    RTConfig.Session.Mode = acquisitionOnly{iMode};
    RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
    RTConfig.Spatial.CombinedMatrixPath = '';
    RTConfig.Source.CTF.ApplyChannelGains = true;
    RTConfig.Source.CTF.ApplyMegRefCorrection = true;
    RTConfig.Source.FieldTrip.RequireCTFRes4 = [];

    RTConfig = nf_finalize_config(RTConfig);
    assert(RTConfig.Source.FieldTrip.RequireCTFRes4 == false, ...
        'Acquisition-only session forced RequireCTFRes4.');
end

end
