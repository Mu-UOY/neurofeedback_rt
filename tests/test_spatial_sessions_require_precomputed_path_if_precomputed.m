function test_spatial_sessions_require_precomputed_path_if_precomputed()
% TEST_SPATIAL_SESSIONS_REQUIRE_PRECOMPUTED_PATH_IF_PRECOMPUTED Check path failure.

%% ===== CHECK SPATIAL SESSIONS =====
% Spatial/RT sessions must not proceed with Precomputed + empty path.
Modes = nf_modes();
spatialSessions = { ...
    Modes.Session.LiveRTDryRun, ...
    Modes.Session.LiveResting, ...
    Modes.Session.LiveTrial, ...
    Modes.Session.LiveSelfTest};

for iMode = 1:numel(spatialSessions)
    RTConfig = nf_live_config();
    RTConfig.Debug.Verbose = false;
    RTConfig.Session.Mode = spatialSessions{iMode};
    RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
    RTConfig.Spatial.CombinedMatrixPath = '';

    didError = false;
    try
        nf_finalize_config(RTConfig);
    catch ME
        didError = true;
        assert(contains(ME.message, 'CombinedMatrixPath'), ...
            'Unexpected precomputed-path error: %s', ME.message);
    end
    assert(didError, 'Spatial/RT session accepted Precomputed + empty path.');
end

end
