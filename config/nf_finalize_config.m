function RTConfig = nf_finalize_config(RTConfig)
% NF_FINALIZE_CONFIG Resolve derived config fields before runtime loops.
%
% DESCRIPTION:
%     Derives path/timing metadata and validates config invariants. This
%     function does not perform live acquisition, source initialization,
%     spatial matrix preparation, feedback setup, logging, or safety loops.

Modes = nf_modes();

%% ===== DERIVE PROJECT AND TIMING FIELDS =====
% These fields are deterministic functions of the config and project layout.
if ~isfield(RTConfig, 'Paths') || ~isstruct(RTConfig.Paths)
    RTConfig.Paths = struct();
end
RTConfig.Paths.ProjectRoot = nf_project_root();

RTConfig.ChunkSamples = round(RTConfig.ChunkSeconds * RTConfig.Fs);
RTConfig.PowerWindowSamples = round(RTConfig.PowerWindowSeconds * RTConfig.Fs);
RTConfig.BufferSamples = round(RTConfig.BufferSeconds * RTConfig.Fs);

%% ===== DERIVE STEP 0 DEVELOPMENT FIELDS =====
if isfield(RTConfig, 'DevelopmentSession') && isstruct(RTConfig.DevelopmentSession)
    RTConfig.DevelopmentSession.Input.TotalChannelCount = ...
        RTConfig.DevelopmentSession.Input.PrimaryMEGChannelCount + ...
        RTConfig.DevelopmentSession.Input.ReferenceMEGChannelCount;
    RTConfig.DevelopmentSession.Transition.TestAdvanceSamples = ...
        RTConfig.DevelopmentSession.Transition.TestAdvanceChunks * RTConfig.ChunkSamples;
    RTConfig.DevelopmentSession.Source.InitialAvailableSamples = ...
        RTConfig.DevelopmentSession.Source.InitialAvailableChunks * RTConfig.ChunkSamples;
    RTConfig.DevelopmentSession.Source.CapacitySamples = ceil( ...
        RTConfig.DevelopmentSession.Source.CapacitySeconds * RTConfig.Fs);
    RTConfig.DevelopmentSession.Source.ReadinessAdvanceSamples = ...
        RTConfig.DevelopmentSession.Source.ReadinessAdvanceChunks * RTConfig.ChunkSamples;
end

%% ===== RESOLVE OPTIONAL HISTORICAL LIVE CONNECTION DEFAULTS =====
% Historical Ben values are explicit opt-in only and are always marked.
RTConfig = local_apply_historical_ben_defaults(RTConfig, Modes);
RTConfig = local_fill_live_fieldtrip_defaults(RTConfig, Modes);

%% ===== ENFORCE LIVE/MOCK-LIVE TIMING =====
% Mock-live uses live timing unless the explicit mock-only escape hatch is set.
isLiveTimingMode = ...
    strcmp(RTConfig.Source.Mode, Modes.Source.LiveFieldTrip) || ...
    strcmp(RTConfig.Source.Mode, Modes.Source.MockLiveBuffer);

if isLiveTimingMode
    isMockTimingEscape = strcmp(RTConfig.Source.Mode, Modes.Source.MockLiveBuffer) && ...
        isfield(RTConfig, 'Debug') && ...
        isfield(RTConfig.Debug, 'AllowNonLiveTimingInMock') && ...
        RTConfig.Debug.AllowNonLiveTimingInMock;

    if ~isMockTimingEscape
        local_require(RTConfig.Fs == 2400, ...
            'Live/mock-live Fs must be 2400 Hz.');

        local_require(RTConfig.ChunkSamples == 480, ...
            '0.2-second chunks at 2400 Hz must be 480 samples.');

        local_require(RTConfig.PowerWindowSamples == 4800, ...
            '2-second window at 2400 Hz must be 4800 samples.');

        local_require(RTConfig.BufferSamples >= RTConfig.PowerWindowSamples, ...
            'BufferSamples must be at least PowerWindowSamples.');

        local_require(mod(RTConfig.PowerWindowSamples, RTConfig.ChunkSamples) == 0, ...
            'PowerWindowSamples must be an integer multiple of ChunkSamples.');
    end
end

%% ===== DERIVE CTF RES4 REQUIREMENT =====
% Acquisition-only sessions must not force CTF metadata.
requiresSpatial = nf_session_requires_spatial(RTConfig);

matrixSource = RTConfig.Spatial.MatrixSource;

usesRealSpatialMatrix = ...
    strcmp(matrixSource, Modes.Spatial.MatrixSource.Precomputed) || ...
    strcmp(matrixSource, Modes.Spatial.MatrixSource.ComputeLive);

usesTechnicalFallback = ...
    strcmp(matrixSource, Modes.Spatial.MatrixSource.TechnicalFallback) || ...
    strcmp(matrixSource, Modes.Spatial.MatrixSource.TechnicalPlaceholder);

usesCTFCorrections = ...
    RTConfig.Source.CTF.ApplyChannelGains || ...
    RTConfig.Source.CTF.ApplyMegRefCorrection || ...
    RTConfig.Source.CTF.ApplyProjector;

if ~isfield(RTConfig.Source.FieldTrip, 'RequireCTFRes4') || ...
        isempty(RTConfig.Source.FieldTrip.RequireCTFRes4)
    if ~requiresSpatial
        RTConfig.Source.FieldTrip.RequireCTFRes4 = false;
    elseif usesCTFCorrections
        RTConfig.Source.FieldTrip.RequireCTFRes4 = true;
    elseif usesRealSpatialMatrix
        RTConfig.Source.FieldTrip.RequireCTFRes4 = true;
    elseif usesTechnicalFallback
        RTConfig.Source.FieldTrip.RequireCTFRes4 = false;
    else
        RTConfig.Source.FieldTrip.RequireCTFRes4 = false;
    end
end

if requiresSpatial && usesTechnicalFallback && usesCTFCorrections
    warning(['Technical fallback is being used with CTF-dependent corrections enabled. ' ...
             'This is allowed only if CTF res4 is available and the correction state is logged.']);
end

if requiresSpatial && usesTechnicalFallback && ~RTConfig.Source.FieldTrip.RequireCTFRes4
    local_require(~RTConfig.Source.CTF.ApplyChannelGains, ...
        'Technical fallback without CTF res4 cannot apply ChannelGains.');

    local_require(~RTConfig.Source.CTF.ApplyMegRefCorrection, ...
        'Technical fallback without CTF res4 cannot apply MegRefCorrection.');

    local_require(~RTConfig.Source.CTF.ApplyProjector, ...
        'Technical fallback without CTF res4 cannot apply projector.');
end

%% ===== CHECK PRECOMPUTED MATRIX PATH RULES =====
% Step 3A-0a validates path presence only; it does not load matrix contents.
if strcmp(matrixSource, Modes.Spatial.MatrixSource.Precomputed)
    local_require(isfield(RTConfig.Spatial, 'CombinedMatrixPath'), ...
        'Spatial.CombinedMatrixPath field is required for precomputed matrix mode.');

    if requiresSpatial
        local_require(~isempty(RTConfig.Spatial.CombinedMatrixPath), ...
            ['Spatial.CombinedMatrixPath must be non-empty for sessions that require spatial processing. ' ...
             'Set a precomputed matrix path or switch MatrixSource to TechnicalFallback.']);

        local_require(exist(RTConfig.Spatial.CombinedMatrixPath, 'file') == 2, ...
            'Spatial.CombinedMatrixPath does not point to an existing file.');
    end
end

%% ===== CHECK TRIAL FAILSAFE SOURCE OF TRUTH =====
% Protocol.Trial.MaxFailsafeSeconds is the only Step 3A-0a failsafe duration.
if ~isfield(RTConfig, 'Protocol') || ~isstruct(RTConfig.Protocol)
    RTConfig.Protocol = struct();
end
if ~isfield(RTConfig.Protocol, 'Trial') || ~isstruct(RTConfig.Protocol.Trial)
    RTConfig.Protocol.Trial = struct();
end
if ~isfield(RTConfig.Protocol.Trial, 'MaxFailsafeSeconds') || ...
        isempty(RTConfig.Protocol.Trial.MaxFailsafeSeconds)
    RTConfig.Protocol.Trial.MaxFailsafeSeconds = 30 * 60;
end

local_require(RTConfig.Protocol.Trial.MaxFailsafeSeconds >= 15 * 60, ...
    'Trial hard failsafe must be at least 15 minutes.');

if RTConfig.Protocol.Trial.MaxFailsafeSeconds > 30 * 60
    warning('Trial hard failsafe is above 30 minutes. Confirm this is intentional.');
end

if isfield(RTConfig, 'LiveTrial') && isstruct(RTConfig.LiveTrial)
    RTConfig.LiveTrial.MaxFailsafeSeconds = RTConfig.Protocol.Trial.MaxFailsafeSeconds;
    if isfield(RTConfig.LiveTrial, 'StopRule')
        RTConfig.LiveTrial.StopRule = RTConfig.Protocol.Trial.StopRule;
    end
end

if isfield(RTConfig, 'Safety') && isfield(RTConfig.Safety, 'MaxDurationSeconds') && ...
        ~isempty(RTConfig.Safety.MaxDurationSeconds)
    local_require(RTConfig.Safety.MaxDurationSeconds == RTConfig.Protocol.Trial.MaxFailsafeSeconds, ...
        ['Do not maintain divergent trial failsafe fields. ' ...
         'Use Protocol.Trial.MaxFailsafeSeconds as source of truth.']);
end

%% ===== MARK FINALIZED AND VALIDATE =====
% nf_check_config performs structural checks after all derived values exist.
if ~isfield(RTConfig, 'Internal') || ~isstruct(RTConfig.Internal)
    RTConfig.Internal = struct();
end
RTConfig.Internal.IsFinalized = true;

RTConfig = nf_check_config(RTConfig);

end

function local_require(condition, message)
% Throw plain errors to match the repository's current assertion style.
if ~condition
    error('%s', message);
end
end

function RTConfig = local_apply_historical_ben_defaults(RTConfig, Modes)
% Fill FieldTrip Host/Port from BenHistorical only when explicitly allowed.
if ~isfield(RTConfig, 'MEGRoom') || ~isstruct(RTConfig.MEGRoom) || ...
        ~isfield(RTConfig.MEGRoom, 'AllowHistoricalBenDefaults') || ...
        ~RTConfig.MEGRoom.AllowHistoricalBenDefaults
    return;
end
if ~isfield(RTConfig.MEGRoom, 'BenHistorical') || ~isstruct(RTConfig.MEGRoom.BenHistorical)
    return;
end
if ~isfield(RTConfig, 'Source') || ~isfield(RTConfig.Source, 'FieldTrip')
    return;
end
if ~isfield(RTConfig.Source.FieldTrip, 'SettingOrigin') || ...
        ~isstruct(RTConfig.Source.FieldTrip.SettingOrigin)
    RTConfig.Source.FieldTrip.SettingOrigin = struct();
end

if (isempty(RTConfig.Source.FieldTrip.Host) || ...
        (ischar(RTConfig.Source.FieldTrip.Host) && isempty(strtrim(RTConfig.Source.FieldTrip.Host)))) && ...
        isfield(RTConfig.MEGRoom.BenHistorical, 'FTHost') && ...
        ~isempty(RTConfig.MEGRoom.BenHistorical.FTHost)
    RTConfig.Source.FieldTrip.Host = RTConfig.MEGRoom.BenHistorical.FTHost;
    RTConfig.Source.FieldTrip.SettingOrigin.Host = Modes.SettingOrigin.HistoricalBen;
    warning('Using historical Ben FieldTrip host because MEGRoom.AllowHistoricalBenDefaults=true.');
end

if isempty(RTConfig.Source.FieldTrip.Port) && ...
        isfield(RTConfig.MEGRoom.BenHistorical, 'FTPort') && ...
        ~isempty(RTConfig.MEGRoom.BenHistorical.FTPort)
    RTConfig.Source.FieldTrip.Port = RTConfig.MEGRoom.BenHistorical.FTPort;
    RTConfig.Source.FieldTrip.SettingOrigin.Port = Modes.SettingOrigin.HistoricalBen;
    warning('Using historical Ben FieldTrip port because MEGRoom.AllowHistoricalBenDefaults=true.');
end
end

function RTConfig = local_fill_live_fieldtrip_defaults(RTConfig, Modes)
% Add new live FieldTrip audit defaults without changing processing settings.
if ~isfield(RTConfig, 'Source') || ~isstruct(RTConfig.Source) || ...
        ~isfield(RTConfig.Source, 'FieldTrip') || ~isstruct(RTConfig.Source.FieldTrip)
    return;
end
if ~isfield(RTConfig.Source.FieldTrip, 'BufferResetPolicy') || ...
        isempty(RTConfig.Source.FieldTrip.BufferResetPolicy)
    RTConfig.Source.FieldTrip.BufferResetPolicy = Modes.BufferResetPolicy.Error;
end
if ~isfield(RTConfig.Source.FieldTrip, 'StreamRole') || ...
        isempty(RTConfig.Source.FieldTrip.StreamRole)
    RTConfig.Source.FieldTrip.StreamRole = Modes.StreamRole.Unknown;
end
end
