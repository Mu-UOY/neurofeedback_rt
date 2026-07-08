function test_acquisition_only_sessions_do_not_require_combined_matrix_path()
% TEST_ACQUISITION_ONLY_SESSIONS_DO_NOT_REQUIRE_COMBINED_MATRIX_PATH Check path rules.

%% ===== CHECK ACQUISITION-ONLY SESSIONS =====
% Acquisition-only checks may run before spatial preparation exists.
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
    RTConfig.Source.FieldTrip.RequireCTFRes4 = [];

    RTConfig = nf_finalize_config(RTConfig);
    assert(strcmp(RTConfig.Session.Mode, acquisitionOnly{iMode}), ...
        'Finalized wrong acquisition-only session mode.');
end

end
