function test_session_requires_spatial()
% TEST_SESSION_REQUIRES_SPATIAL Check session-scoped spatial requirements.

%% ===== CHECK ACQUISITION-ONLY SESSIONS =====
% Header/channel/chunk checks should not require an IPS matrix.
Modes = nf_modes();
RTConfig = nf_live_config();

acquisitionOnly = { ...
    Modes.Session.LiveDiagnostics, ...
    Modes.Session.LiveChannelCheck, ...
    Modes.Session.LiveChunkSmokeTest};
for iMode = 1:numel(acquisitionOnly)
    RTConfig.Session.Mode = acquisitionOnly{iMode};
    assert(~nf_session_requires_spatial(RTConfig), ...
        'Acquisition-only session unexpectedly required spatial processing.');
end

%% ===== CHECK SPATIAL/RT SESSIONS =====
% RT sessions need a spatial path or a selected technical fallback.
spatialSessions = { ...
    Modes.Session.LiveRTDryRun, ...
    Modes.Session.LiveResting, ...
    Modes.Session.LiveTrial, ...
    Modes.Session.LiveSelfTest};
for iMode = 1:numel(spatialSessions)
    RTConfig.Session.Mode = spatialSessions{iMode};
    assert(nf_session_requires_spatial(RTConfig), ...
        'Spatial/RT session did not require spatial processing.');
end

end
