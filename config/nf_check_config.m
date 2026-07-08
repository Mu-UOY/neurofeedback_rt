function RTConfig = nf_check_config(RTConfig)
% NF_CHECK_CONFIG Validate a real-time neurofeedback configuration.
%
% USAGE:  RTConfig = nf_check_config(RTConfig)
%
% DESCRIPTION:
%     Verifies required RTConfig fields, validates numeric ranges and mode
%     names, checks optional dependencies, and creates configured output
%     folders before processing starts.

%% ===== CHECK CONFIG STRUCT =====
% All downstream code expects RTConfig to be a struct with named sections.
if ~isstruct(RTConfig)
    error('RTConfig must be a struct.');
end

%% ===== CHECK REQUIRED SECTIONS =====
% These top-level fields are used across source, filter, spatial, and output code.
required = {'Fs','ChunkSamples','PowerWindowSamples','BufferSamples', ...
    'TargetBand','Filter','Source','Spatial','ZScore','Debug','Paths'};
for i = 1:numel(required)
    if ~isfield(RTConfig, required{i})
        error('RTConfig missing required field: %s', required{i});
    end
end

%% ===== FILL DEFENSIVE DEFAULTS =====
% Optional fields may be missing from configs saved before this layer existed.
RTConfig = local_fill_step1_defaults(RTConfig);

%% ===== RESOLVE FINALIZATION STATE =====
% Raw live configs may contain sentinels that are resolved by nf_finalize_config.
isFinalized = isfield(RTConfig, 'Internal') && ...
              isfield(RTConfig.Internal, 'IsFinalized') && ...
              isequal(RTConfig.Internal.IsFinalized, true);

%% ===== CHECK TIMING PARAMETERS =====
% Fs is the source sampling rate in Hz.
if ~isscalar(RTConfig.Fs) || ~isnumeric(RTConfig.Fs) || ~isfinite(RTConfig.Fs) || RTConfig.Fs <= 0
    error('RTConfig.Fs must be a finite positive numeric scalar.');
end

% ChunkSamples is the number of samples processed per real-time update.
if ~isscalar(RTConfig.ChunkSamples) || RTConfig.ChunkSamples <= 0 || RTConfig.ChunkSamples ~= round(RTConfig.ChunkSamples)
    error('RTConfig.ChunkSamples must be a positive integer scalar.');
end
if RTConfig.ChunkSamples > RTConfig.Fs
    warning('RTConfig.ChunkSamples is longer than one second of data.');
end

% PowerWindowSamples controls the sliding window used for power estimates.
if ~isscalar(RTConfig.PowerWindowSamples) || RTConfig.PowerWindowSamples <= 0 || RTConfig.PowerWindowSamples ~= round(RTConfig.PowerWindowSamples)
    error('RTConfig.PowerWindowSamples must be a positive integer scalar.');
end

% BufferSamples must be large enough to hold at least one power window.
if ~isscalar(RTConfig.BufferSamples) || RTConfig.BufferSamples < RTConfig.PowerWindowSamples
    error('RTConfig.BufferSamples must be at least RTConfig.PowerWindowSamples.');
end

%% ===== CHECK TARGET BAND =====
% TargetBand is [low high] in Hz and must fit below Nyquist.
if ~isnumeric(RTConfig.TargetBand) || numel(RTConfig.TargetBand) ~= 2
    error('RTConfig.TargetBand must be [low high] in Hz.');
end
if RTConfig.TargetBand(1) < 0 || RTConfig.TargetBand(1) >= RTConfig.TargetBand(2)
    error('RTConfig.TargetBand must satisfy 0 <= low < high.');
end
if RTConfig.TargetBand(2) >= RTConfig.Fs / 2
    error('RTConfig.TargetBand upper edge must be below Nyquist.');
end

%% ===== CHECK FILTER CONFIGURATION =====
% Only explicitly supported filter implementations are accepted.
allowedFilters = {'none','iir_sos','brainstorm_fir'};
if ~isfield(RTConfig.Filter, 'Type') || ~ismember(RTConfig.Filter.Type, allowedFilters)
    error('RTConfig.Filter.Type must be one of: %s.', strjoin(allowedFilters, ', '));
end

% iir_sos depends on Signal Processing Toolbox functions.
if strcmp(RTConfig.Filter.Type, 'iir_sos')
    if exist('sosfilt', 'file') == 0 && exist('sosfilt', 'builtin') == 0
        error(['Filter.Type = iir_sos requires sosfilt, usually from the Signal Processing Toolbox. ', ...
            'Use Filter.Type = none or install the toolbox.']);
    end
    if exist('butter', 'file') == 0 && exist('butter', 'builtin') == 0
        error('Filter.Type = iir_sos requires butter, usually from the Signal Processing Toolbox.');
    end
end

% Brainstorm FIR runtime mode is load-only until direct Brainstorm calls are wired.
if strcmp(RTConfig.Filter.Type, 'brainstorm_fir')
    if ~isfield(RTConfig.Brainstorm, 'FilterSpecPath') || ...
            isempty(RTConfig.Brainstorm.FilterSpecPath) || ...
            exist(RTConfig.Brainstorm.FilterSpecPath, 'file') == 0
        error(['Filter.Type = brainstorm_fir currently requires RTConfig.Brainstorm.FilterSpecPath. ', ...
            'Direct Brainstorm function calls are not wired until the local function signature is manually verified.']);
    end
end

% Empirical and explicit delay-correction fields are optional scalar metadata.
if isfield(RTConfig.Filter, 'EmpiricalDelaySamples') && ...
        ~local_is_empty_nan_or_finite_scalar(RTConfig.Filter.EmpiricalDelaySamples)
    error('RTConfig.Filter.EmpiricalDelaySamples must be empty, NaN, or a finite numeric scalar.');
end
if isfield(RTConfig.Filter, 'DelayCorrectionUsed') && ...
        ~local_is_empty_nan_or_finite_scalar(RTConfig.Filter.DelayCorrectionUsed)
    error('RTConfig.Filter.DelayCorrectionUsed must be empty, NaN, or a finite numeric scalar.');
end

%% ===== CHECK STEP 1 VALIDATION CONFIGURATION =====
% Offline scientific checks are optional but must have valid local settings.
if ~isscalar(RTConfig.Validation.Step1.WindowSamples) || ...
        RTConfig.Validation.Step1.WindowSamples <= 0 || ...
        RTConfig.Validation.Step1.WindowSamples ~= round(RTConfig.Validation.Step1.WindowSamples)
    error('RTConfig.Validation.Step1.WindowSamples must be a positive integer scalar.');
end
if ~isscalar(RTConfig.Validation.Step1.StepSamples) || ...
        RTConfig.Validation.Step1.StepSamples <= 0 || ...
        RTConfig.Validation.Step1.StepSamples ~= round(RTConfig.Validation.Step1.StepSamples)
    error('RTConfig.Validation.Step1.StepSamples must be a positive integer scalar.');
end

allowedReferenceStrideModes = {'dense','step'};
if ~isfield(RTConfig.Validation.Step1, 'ReferenceStrideMode') || ...
        isempty(RTConfig.Validation.Step1.ReferenceStrideMode)
    RTConfig.Validation.Step1.ReferenceStrideMode = 'dense';
end
RTConfig.Validation.Step1.ReferenceStrideMode = lower(char(RTConfig.Validation.Step1.ReferenceStrideMode));
if ~ismember(RTConfig.Validation.Step1.ReferenceStrideMode, allowedReferenceStrideModes)
    error('Unknown ReferenceStrideMode: %s', RTConfig.Validation.Step1.ReferenceStrideMode);
end
if strcmp(RTConfig.Validation.Step1.ReferenceStrideMode, 'step')
    RTConfig.Validation.Step1.ReferenceStepSamples = local_resolve_reference_step_samples(RTConfig);
end

allowedBrainstormModes = {'auto','skip','precomputed_filtered','bst_function','filter_spec','iir_self_test'};
if ~isfield(RTConfig.Validation.Step1.Brainstorm, 'Mode') || ...
        ~ismember(RTConfig.Validation.Step1.Brainstorm.Mode, allowedBrainstormModes)
    error('RTConfig.Validation.Step1.Brainstorm.Mode must be one of: %s.', ...
        strjoin(allowedBrainstormModes, ', '));
end

%% ===== CHECK SIMULATION CONFIGURATION =====
% Dropped-chunk simulation can be deterministic or probabilistic.
if ~isfield(RTConfig, 'Simulation') || ~isstruct(RTConfig.Simulation)
    error('RTConfig.Simulation must be a struct.');
end
if ~islogical(RTConfig.Simulation.EnableDroppedChunks) && ...
        ~(isnumeric(RTConfig.Simulation.EnableDroppedChunks) && isscalar(RTConfig.Simulation.EnableDroppedChunks))
    error('RTConfig.Simulation.EnableDroppedChunks must be a scalar logical or numeric flag.');
end
if ~isscalar(RTConfig.Simulation.DropProbability) || ~isnumeric(RTConfig.Simulation.DropProbability) || ...
        ~isfinite(RTConfig.Simulation.DropProbability) || RTConfig.Simulation.DropProbability < 0 || ...
        RTConfig.Simulation.DropProbability > 1
    error('RTConfig.Simulation.DropProbability must be a finite scalar between 0 and 1.');
end
if ~isempty(RTConfig.Simulation.DropChunkIndices)
    dropIdx = RTConfig.Simulation.DropChunkIndices;
    if ~isnumeric(dropIdx) || ~isvector(dropIdx) || any(~isfinite(dropIdx(:))) || ...
            any(dropIdx(:) < 1) || any(dropIdx(:) ~= round(dropIdx(:)))
        error('RTConfig.Simulation.DropChunkIndices must be empty or a vector of positive integer values.');
    end
end
if ~isempty(RTConfig.Simulation.RandomSeed)
    seed = RTConfig.Simulation.RandomSeed;
    if ~isnumeric(seed) || ~isscalar(seed) || ~isfinite(seed) || ...
            seed ~= round(seed) || seed < 0
        error('RTConfig.Simulation.RandomSeed must be empty or a finite nonnegative scalar integer.');
    end
end

%% ===== CHECK SOURCE CONFIGURATION =====
% Source.Mode selects simulated replay or a future live adapter.
allowedModes = {'offline_full','simulated_online','simulated_resting', ...
    'simulated_trial','live_fieldtrip','live_brainstorm','mock_live_buffer'};
if ~isfield(RTConfig.Source, 'Mode') || ~ismember(RTConfig.Source.Mode, allowedModes)
    error('RTConfig.Source.Mode must be one of: %s.', strjoin(allowedModes, ', '));
end

% When a dataset path is set, fail early if it cannot be loaded.
if isfield(RTConfig.Source, 'DatasetPath') && ~isempty(RTConfig.Source.DatasetPath) && exist(RTConfig.Source.DatasetPath, 'file') == 0
    error('Dataset file does not exist: %s', RTConfig.Source.DatasetPath);
end

%% ===== CHECK SPATIAL CONFIGURATION =====
% Spatial.Mode controls how channel data are projected before filtering.
allowedSpatial = {'identity','single_channel','channel_average','combined_matrix'};
if ~isfield(RTConfig.Spatial, 'Mode') || ~ismember(RTConfig.Spatial.Mode, allowedSpatial)
    error('RTConfig.Spatial.Mode must be one of: %s.', strjoin(allowedSpatial, ', '));
end

%% ===== CHECK Z-SCORE CONFIGURATION =====
% Clipping bounds and smoothing alpha are used after power estimation.
if ~isnumeric(RTConfig.ZScore.ClipRange) || numel(RTConfig.ZScore.ClipRange) ~= 2 || ...
        RTConfig.ZScore.ClipRange(1) >= RTConfig.ZScore.ClipRange(2)
    error('RTConfig.ZScore.ClipRange must be [low high] with low < high.');
end
if ~isscalar(RTConfig.ZScore.SmoothAlpha) || RTConfig.ZScore.SmoothAlpha < 0 || RTConfig.ZScore.SmoothAlpha >= 1
    error('RTConfig.ZScore.SmoothAlpha must satisfy 0 <= alpha < 1.');
end

%% ===== CHECK BASELINE CONFIGURATION =====
% Simulated resting/trial uses finalized baselines for z-scoring.
if ~isfield(RTConfig, 'Baseline') || ~isstruct(RTConfig.Baseline)
    error('RTConfig.Baseline must be a struct.');
end
if ~isscalar(RTConfig.Baseline.MinValidWindows) || ~isnumeric(RTConfig.Baseline.MinValidWindows) || ...
        ~isfinite(RTConfig.Baseline.MinValidWindows) || RTConfig.Baseline.MinValidWindows < 1 || ...
        RTConfig.Baseline.MinValidWindows ~= round(RTConfig.Baseline.MinValidWindows)
    error('RTConfig.Baseline.MinValidWindows must be a positive integer scalar.');
end
allowedOutlierMethods = {'none','percentile','zscore'};
if ~isfield(RTConfig.Baseline, 'OutlierMethod') || ...
        ~ismember(char(RTConfig.Baseline.OutlierMethod), allowedOutlierMethods)
    error('RTConfig.Baseline.OutlierMethod must be one of: %s.', strjoin(allowedOutlierMethods, ', '));
end
lowPct = RTConfig.Baseline.OutlierPercentileLow;
highPct = RTConfig.Baseline.OutlierPercentileHigh;
if ~isscalar(lowPct) || ~isscalar(highPct) || ~isnumeric(lowPct) || ~isnumeric(highPct) || ...
        ~isfinite(lowPct) || ~isfinite(highPct) || lowPct < 0 || highPct > 100 || lowPct >= highPct
    error('RTConfig.Baseline.OutlierPercentileLow/High must satisfy 0 <= low < high <= 100.');
end
if ~isscalar(RTConfig.Baseline.OutlierZThreshold) || ~isnumeric(RTConfig.Baseline.OutlierZThreshold) || ...
        ~isfinite(RTConfig.Baseline.OutlierZThreshold) || RTConfig.Baseline.OutlierZThreshold <= 0
    error('RTConfig.Baseline.OutlierZThreshold must be finite and > 0.');
end
if ~local_is_scalar_logical_or_numeric_flag(RTConfig.Baseline.RequireConfigHashMatch)
    error('RTConfig.Baseline.RequireConfigHashMatch must be a scalar logical or numeric flag.');
end
if ~(isempty(RTConfig.Baseline.Path) || ischar(RTConfig.Baseline.Path) || isstring(RTConfig.Baseline.Path))
    error('RTConfig.Baseline.Path must be empty, char, or string.');
end

%% ===== CHECK FEEDBACK CONFIGURATION =====
% Step 2B feedback is a non-UI mapping layer only.
if ~isfield(RTConfig, 'Feedback') || ~isstruct(RTConfig.Feedback)
    error('RTConfig.Feedback must be a struct.');
end
allowedFeedbackModes = {'none','debug_value','local_circle','debug_plot', ...
    'external_udp','external_serial','external_parallel'};
if ~isfield(RTConfig.Feedback, 'Mode') || ~ismember(char(RTConfig.Feedback.Mode), allowedFeedbackModes)
    error('RTConfig.Feedback.Mode must be one of: %s.', strjoin(allowedFeedbackModes, ', '));
end
if ~isscalar(RTConfig.Feedback.UpdateEveryNValidMeasures) || ...
        ~isnumeric(RTConfig.Feedback.UpdateEveryNValidMeasures) || ...
        ~isfinite(RTConfig.Feedback.UpdateEveryNValidMeasures) || ...
        RTConfig.Feedback.UpdateEveryNValidMeasures < 1 || ...
        RTConfig.Feedback.UpdateEveryNValidMeasures ~= round(RTConfig.Feedback.UpdateEveryNValidMeasures)
    error('RTConfig.Feedback.UpdateEveryNValidMeasures must be a positive integer scalar.');
end
allowedMapSources = {'ZSmoothed','ZClipped','ZRaw'};
if ~isfield(RTConfig.Feedback, 'MapSource') || ~ismember(char(RTConfig.Feedback.MapSource), allowedMapSources)
    error('RTConfig.Feedback.MapSource must be one of: %s.', strjoin(allowedMapSources, ', '));
end
if ~isnumeric(RTConfig.Feedback.ClipRange) || numel(RTConfig.Feedback.ClipRange) ~= 2 || ...
        RTConfig.Feedback.ClipRange(1) >= RTConfig.Feedback.ClipRange(2)
    error('RTConfig.Feedback.ClipRange must be [low high] with low < high.');
end

%% ===== CHECK LIVE CONFIG SCAFFOLD =====
% Step 3A-0a validates live/mock-live config only; it does not acquire data.
local_check_live_config_scaffold(RTConfig, isFinalized);

%% ===== CHECK ANALYSIS CONFIGURATION =====
% Step 2C analysis runs are noninteractive unless explicitly requested.
if ~isfield(RTConfig, 'Analysis') || ~isstruct(RTConfig.Analysis)
    error('RTConfig.Analysis must be a struct.');
end
allowedDisplayModes = {'off','interactive'};
if ~isfield(RTConfig.Analysis, 'DisplayMode') || ...
        ~ismember(char(RTConfig.Analysis.DisplayMode), allowedDisplayModes)
    error('RTConfig.Analysis.DisplayMode must be one of: %s.', strjoin(allowedDisplayModes, ', '));
end

%% ===== CHECK SESSION METADATA =====
% Metadata fields may be empty, but the section should exist for audit code.
if ~isfield(RTConfig, 'SessionMetadata') || ~isstruct(RTConfig.SessionMetadata)
    error('RTConfig.SessionMetadata must be a struct.');
end

%% ===== ENSURE OUTPUT PATHS =====
% Create configured output folders so later save operations do not fail.
pathFields = {'OutputDir','ValidationDir','BaselinesDir','TrialsDir'};
for i = 1:numel(pathFields)
    fieldName = pathFields{i};
    if isfield(RTConfig.Paths, fieldName) && ~exist(RTConfig.Paths.(fieldName), 'dir')
        mkdir(RTConfig.Paths.(fieldName));
    end
end

%% ===== PRINT SUMMARY =====
% Keep the same terse confirmation used by the validation entry point.
if isfield(RTConfig.Debug, 'Verbose') && RTConfig.Debug.Verbose
fprintf('Config OK\n');
end

end

function local_check_live_config_scaffold(RTConfig, isFinalized)
% Validate Step 3A-0a live/mock-live config fields without runtime calls.
Modes = nf_modes();

sourceMode = char(RTConfig.Source.Mode);
isLiveFieldTrip = strcmp(sourceMode, Modes.Source.LiveFieldTrip);
isMockLive = strcmp(sourceMode, Modes.Source.MockLiveBuffer);
if ~(isLiveFieldTrip || isMockLive)
    return;
end

%% ===== CHECK REQUIRED LIVE SECTIONS =====
% These structs are explicit audit fields for later live-room logs.
requiredSections = {'Internal','Session','MockLive','Protocol','Logging', ...
    'LiveDryRun','Safety','Comm'};
for iField = 1:numel(requiredSections)
    fieldName = requiredSections{iField};
    if ~isfield(RTConfig, fieldName) || ~isstruct(RTConfig.(fieldName))
        error('RTConfig.%s must be a struct for live/mock-live configs.', fieldName);
    end
end
local_require_field(RTConfig.Source, {'LiveAdapter'}, 'RTConfig.Source.LiveAdapter');
local_require_field(RTConfig.Source, {'Benjamin'}, 'RTConfig.Source.Benjamin');
local_require_field(RTConfig.Source, {'FieldTrip'}, 'RTConfig.Source.FieldTrip');
local_require_field(RTConfig.Source, {'CTF'}, 'RTConfig.Source.CTF');

allowedSessions = { ...
    Modes.Session.LiveDiagnostics, ...
    Modes.Session.LiveChannelCheck, ...
    Modes.Session.LiveChunkSmokeTest, ...
    Modes.Session.LiveRTDryRun, ...
    Modes.Session.LiveSelfTest, ...
    Modes.Session.LiveResting, ...
    Modes.Session.LiveTrial};
if ~isfield(RTConfig.Session, 'Mode') || ~ismember(char(RTConfig.Session.Mode), allowedSessions)
    error('RTConfig.Session.Mode must be one of: %s.', strjoin(allowedSessions, ', '));
end

%% ===== CHECK SOURCE MODE AND ADAPTER =====
% The source mode can change later, but the RT core interface stays fixed.
allowedLiveAdapters = {Modes.LiveAdapter.BenFieldTrip, Modes.LiveAdapter.MockBuffer};
if ~ismember(char(RTConfig.Source.LiveAdapter), allowedLiveAdapters)
    error('RTConfig.Source.LiveAdapter must be one of: %s.', strjoin(allowedLiveAdapters, ', '));
end
if isLiveFieldTrip && ~strcmp(RTConfig.Source.LiveAdapter, Modes.LiveAdapter.BenFieldTrip)
    error('LiveFieldTrip requires Source.LiveAdapter = ben_fieldtrip_buffer.');
end
if isMockLive && ~strcmp(RTConfig.Source.LiveAdapter, Modes.LiveAdapter.MockBuffer)
    error('MockLiveBuffer requires Source.LiveAdapter = mock_buffer.');
end

%% ===== CHECK LIVE CONNECTION CONFIG =====
% Editable live connection settings stay in nf_live_config/RTConfig only.
local_require_field(RTConfig.Source.Benjamin, {'CodeRoot'}, ...
    'RTConfig.Source.Benjamin.CodeRoot');
local_require_field(RTConfig.Source.Benjamin, {'WiringNotes'}, ...
    'RTConfig.Source.Benjamin.WiringNotes');
local_require_field(RTConfig.Source.Benjamin, {'WiringEvidenceFiles'}, ...
    'RTConfig.Source.Benjamin.WiringEvidenceFiles');
local_check_optional_text(RTConfig.Source.Benjamin.CodeRoot, ...
    'RTConfig.Source.Benjamin.CodeRoot');
local_check_cell_array(RTConfig.Source.Benjamin.WiringNotes, ...
    'RTConfig.Source.Benjamin.WiringNotes');
local_check_cell_array(RTConfig.Source.Benjamin.WiringEvidenceFiles, ...
    'RTConfig.Source.Benjamin.WiringEvidenceFiles');

fieldTripFields = {'Host','Port','TimeoutMs','BufferMPath','FieldTripRoot', ...
    'RequiredBufferRoot','AllowAlreadyOnPathBuffer','AllowMatlabToolboxBuffer', ...
    'UseBrainstormPluginPaths','UseCTFRes4FromHeader','RequireCTFRes4', ...
    'TestBufferFcn','SettingOrigin'};
for iField = 1:numel(fieldTripFields)
    local_require_field(RTConfig.Source.FieldTrip, fieldTripFields(iField), ...
        ['RTConfig.Source.FieldTrip.' fieldTripFields{iField}]);
end
local_require_field(RTConfig.Source.FieldTrip, {'UseCTFRes4FromHeader'}, ...
    'RTConfig.Source.FieldTrip.UseCTFRes4FromHeader');
local_require_field(RTConfig.Source.FieldTrip, {'RequireCTFRes4'}, ...
    'RTConfig.Source.FieldTrip.RequireCTFRes4');

hasTestBufferFcn = ~isempty(RTConfig.Source.FieldTrip.TestBufferFcn);
if hasTestBufferFcn && ~isa(RTConfig.Source.FieldTrip.TestBufferFcn, 'function_handle')
    error('RTConfig.Source.FieldTrip.TestBufferFcn must be empty or a function_handle.');
end

if isLiveFieldTrip && ~hasTestBufferFcn
    local_check_nonempty_text(RTConfig.Source.FieldTrip.Host, ...
        'RTConfig.Source.FieldTrip.Host');
    local_check_positive_integer(RTConfig.Source.FieldTrip.Port, ...
        'RTConfig.Source.FieldTrip.Port');
else
    local_check_optional_text(RTConfig.Source.FieldTrip.Host, ...
        'RTConfig.Source.FieldTrip.Host');
    if ~isempty(RTConfig.Source.FieldTrip.Port)
        local_check_positive_integer(RTConfig.Source.FieldTrip.Port, ...
            'RTConfig.Source.FieldTrip.Port');
    end
end

local_check_positive_numeric(RTConfig.Source.FieldTrip.TimeoutMs, 'RTConfig.Source.FieldTrip.TimeoutMs');
local_check_optional_text(RTConfig.Source.FieldTrip.BufferMPath, ...
    'RTConfig.Source.FieldTrip.BufferMPath');
local_check_optional_text(RTConfig.Source.FieldTrip.FieldTripRoot, ...
    'RTConfig.Source.FieldTrip.FieldTripRoot');
local_check_optional_text(RTConfig.Source.FieldTrip.RequiredBufferRoot, ...
    'RTConfig.Source.FieldTrip.RequiredBufferRoot');
local_check_scalar_logical(RTConfig.Source.FieldTrip.AllowAlreadyOnPathBuffer, ...
    'RTConfig.Source.FieldTrip.AllowAlreadyOnPathBuffer');
local_check_scalar_logical(RTConfig.Source.FieldTrip.AllowMatlabToolboxBuffer, ...
    'RTConfig.Source.FieldTrip.AllowMatlabToolboxBuffer');
local_check_scalar_logical(RTConfig.Source.FieldTrip.UseBrainstormPluginPaths, ...
    'RTConfig.Source.FieldTrip.UseBrainstormPluginPaths');
local_check_scalar_logical(RTConfig.Source.FieldTrip.UseCTFRes4FromHeader, ...
    'RTConfig.Source.FieldTrip.UseCTFRes4FromHeader');
local_check_setting_origin_fields(RTConfig.Source.FieldTrip.SettingOrigin);
if isFinalized
    local_check_scalar_logical(RTConfig.Source.FieldTrip.RequireCTFRes4, ...
        'RTConfig.Source.FieldTrip.RequireCTFRes4');
elseif ~(isempty(RTConfig.Source.FieldTrip.RequireCTFRes4) || ...
        local_is_scalar_logical(RTConfig.Source.FieldTrip.RequireCTFRes4))
    error('RTConfig.Source.FieldTrip.RequireCTFRes4 must be empty or a scalar logical before finalization.');
end

%% ===== CHECK PROCESSING AND DEBUG CONFIG =====
% Live/mock-live Step 3A-0a config is restricted to the existing IIR/SOS core.
if ~strcmp(RTConfig.Filter.Type, Modes.Filter.IIRSOS)
    error('Live/mock-live Filter.Type must be iir_sos.');
end
debugFlags = {'CheckMeasureSchema','CheckRTSchema','Verbose','AllowNonLiveTimingInMock'};
for iFlag = 1:numel(debugFlags)
    fieldName = debugFlags{iFlag};
    local_require_field(RTConfig.Debug, {fieldName}, ['RTConfig.Debug.' fieldName]);
    local_check_scalar_logical(RTConfig.Debug.(fieldName), ['RTConfig.Debug.' fieldName]);
end
local_check_positive_integer(RTConfig.Debug.SaveFirstChunksForCorrectionValidation, ...
    'RTConfig.Debug.SaveFirstChunksForCorrectionValidation');

%% ===== CHECK CTF CORRECTION CONFIG =====
% These are config-only switches in Step 3A-0a.
ctfFlags = {'ApplyChannelGains','ApplyMegRefCorrection','RemoveBlockMean', ...
    'ApplyProjector','RequireMarcConfirmation','MarcConfirmed'};
for iFlag = 1:numel(ctfFlags)
    fieldName = ctfFlags{iFlag};
    local_require_field(RTConfig.Source.CTF, {fieldName}, ['RTConfig.Source.CTF.' fieldName]);
    local_check_scalar_logical(RTConfig.Source.CTF.(fieldName), ['RTConfig.Source.CTF.' fieldName]);
end
local_require_field(RTConfig.Source.CTF, {'CorrectionOrder'}, ...
    'RTConfig.Source.CTF.CorrectionOrder');
if ~iscell(RTConfig.Source.CTF.CorrectionOrder) || isempty(RTConfig.Source.CTF.CorrectionOrder)
    error('RTConfig.Source.CTF.CorrectionOrder must be a nonempty cell array.');
end

%% ===== CHECK LIVE TIMING =====
% Raw configs may be inspected before finalization; finalized configs must be exact.
secondsFields = {'ChunkSeconds','PowerWindowSeconds','BufferSeconds'};
for iField = 1:numel(secondsFields)
    fieldName = secondsFields{iField};
    if ~isfield(RTConfig, fieldName)
        error('RTConfig.%s is required for live/mock-live configs.', fieldName);
    end
    local_check_positive_numeric(RTConfig.(fieldName), ['RTConfig.' fieldName]);
end

if isFinalized
    local_check_finalized_live_timing(RTConfig, isMockLive);
end

%% ===== CHECK SPATIAL CONTRACT =====
% Technical fallback is still a combined_matrix path selected by MatrixSource.
if ~strcmp(RTConfig.Spatial.Mode, Modes.Spatial.CombinedMatrix)
    error('Live/mock-live Spatial.Mode must be combined_matrix.');
end
local_require_field(RTConfig.Spatial, {'MatrixSource'}, 'RTConfig.Spatial.MatrixSource');
allowedMatrixSources = { ...
    Modes.Spatial.MatrixSource.ComputeLive, ...
    Modes.Spatial.MatrixSource.Precomputed, ...
    Modes.Spatial.MatrixSource.TechnicalFallback, ...
    Modes.Spatial.MatrixSource.TechnicalPlaceholder};
if ~ismember(char(RTConfig.Spatial.MatrixSource), allowedMatrixSources)
    error('RTConfig.Spatial.MatrixSource must be one of: %s.', strjoin(allowedMatrixSources, ', '));
end

matrixSource = char(RTConfig.Spatial.MatrixSource);
usesRealSpatialMatrix = strcmp(matrixSource, Modes.Spatial.MatrixSource.Precomputed) || ...
    strcmp(matrixSource, Modes.Spatial.MatrixSource.ComputeLive);
usesTechnicalFallback = strcmp(matrixSource, Modes.Spatial.MatrixSource.TechnicalFallback) || ...
    strcmp(matrixSource, Modes.Spatial.MatrixSource.TechnicalPlaceholder);

if strcmp(matrixSource, Modes.Spatial.MatrixSource.Precomputed)
    local_require_field(RTConfig.Spatial, {'CombinedMatrixPath'}, ...
        'RTConfig.Spatial.CombinedMatrixPath');
end
if usesTechnicalFallback
    local_check_fallback_fields(RTConfig);
end

requiresSpatial = nf_session_requires_spatial(RTConfig);
if isFinalized && strcmp(matrixSource, Modes.Spatial.MatrixSource.Precomputed) && requiresSpatial
    if isempty(RTConfig.Spatial.CombinedMatrixPath)
        error(['Spatial.CombinedMatrixPath must be non-empty for sessions that require spatial processing. ' ...
            'Set a precomputed matrix path or switch MatrixSource to TechnicalFallback.']);
    end
    if exist(RTConfig.Spatial.CombinedMatrixPath, 'file') ~= 2
        error('Spatial.CombinedMatrixPath does not point to an existing file.');
    end
end

%% ===== CHECK FINALIZED CTF RES4 LOGIC =====
% Acquisition-only sessions intentionally do not force CTF metadata.
usesCTFCorrections = RTConfig.Source.CTF.ApplyChannelGains || ...
    RTConfig.Source.CTF.ApplyMegRefCorrection || ...
    RTConfig.Source.CTF.ApplyProjector;

if isFinalized
    requireCTFRes4 = RTConfig.Source.FieldTrip.RequireCTFRes4;
    if ~requiresSpatial
        if requireCTFRes4
            error('Acquisition-only live sessions must not force RequireCTFRes4.');
        end
    elseif usesCTFCorrections || usesRealSpatialMatrix
        if ~requireCTFRes4
            error('Spatial/RT sessions with CTF corrections or real spatial matrices require CTF res4.');
        end
    elseif usesTechnicalFallback && ~usesCTFCorrections
        if requireCTFRes4
            error('Technical fallback without CTF corrections should not require CTF res4.');
        end
    end

    if requiresSpatial && usesTechnicalFallback && ~requireCTFRes4
        if RTConfig.Source.CTF.ApplyChannelGains
            error('Technical fallback without CTF res4 cannot apply ChannelGains.');
        end
        if RTConfig.Source.CTF.ApplyMegRefCorrection
            error('Technical fallback without CTF res4 cannot apply MegRefCorrection.');
        end
        if RTConfig.Source.CTF.ApplyProjector
            error('Technical fallback without CTF res4 cannot apply projector.');
        end
    end
end

%% ===== CHECK FEEDBACK CONFIG FIELDS =====
% Feedback setup itself is intentionally deferred to later steps.
if ~isfield(RTConfig.Feedback, 'RequirePsychtoolboxForLive') || ...
        ~isfield(RTConfig.Feedback, 'AllowDebugPlotFallback')
    error('Live/mock-live feedback flags are required.');
end
local_check_scalar_logical(RTConfig.Feedback.RequirePsychtoolboxForLive, ...
    'RTConfig.Feedback.RequirePsychtoolboxForLive');
local_check_scalar_logical(RTConfig.Feedback.AllowDebugPlotFallback, ...
    'RTConfig.Feedback.AllowDebugPlotFallback');
local_check_feedback_circle_fields(RTConfig);

%% ===== CHECK PROTOCOL, LOGGING, MOCK-LIVE, SAFETY =====
% These fields are explicit configuration only in Step 3A-0a.
allowedStopRules = {Modes.TrialStop.Manual, Modes.TrialStop.ManualOrSuccess, ...
    Modes.TrialStop.FixedDuration};
if ~isfield(RTConfig.Protocol, 'Trial') || ~isstruct(RTConfig.Protocol.Trial)
    error('RTConfig.Protocol.Trial must be a struct.');
end
if ~isfield(RTConfig.Protocol.Trial, 'StopRule') || ...
        ~ismember(char(RTConfig.Protocol.Trial.StopRule), allowedStopRules)
    error('RTConfig.Protocol.Trial.StopRule must be one of: %s.', strjoin(allowedStopRules, ', '));
end
if ~isfield(RTConfig.Protocol.Trial, 'MaxFailsafeSeconds') || ...
        ~isscalar(RTConfig.Protocol.Trial.MaxFailsafeSeconds) || ...
        ~isnumeric(RTConfig.Protocol.Trial.MaxFailsafeSeconds) || ...
        ~isfinite(RTConfig.Protocol.Trial.MaxFailsafeSeconds) || ...
        RTConfig.Protocol.Trial.MaxFailsafeSeconds < 15 * 60
    error('RTConfig.Protocol.Trial.MaxFailsafeSeconds must be at least 15 minutes.');
end
if isfield(RTConfig.Safety, 'MaxDurationSeconds') && ...
        ~isempty(RTConfig.Safety.MaxDurationSeconds) && ...
        RTConfig.Safety.MaxDurationSeconds ~= RTConfig.Protocol.Trial.MaxFailsafeSeconds
    error(['Do not maintain divergent trial failsafe fields. ' ...
        'Use Protocol.Trial.MaxFailsafeSeconds as source of truth.']);
end

local_check_mock_live_fields(RTConfig);
local_check_logging_fields(RTConfig);
local_check_live_dry_run_fields(RTConfig);
local_check_safety_fields(RTConfig);
local_check_scalar_logical(RTConfig.Comm.EnableTriggers, 'RTConfig.Comm.EnableTriggers');

if isFinalized
    if ~isfield(RTConfig.Paths, 'ProjectRoot') || isempty(RTConfig.Paths.ProjectRoot) || ...
            exist(RTConfig.Paths.ProjectRoot, 'dir') == 0
        error('Finalized configs require RTConfig.Paths.ProjectRoot to be an existing folder.');
    end
end
end

function local_check_finalized_live_timing(RTConfig, isMockLive)
% Enforce live timing after derived sample counts have been resolved.
isMockTimingEscape = isMockLive && ...
    isfield(RTConfig.Debug, 'AllowNonLiveTimingInMock') && ...
    RTConfig.Debug.AllowNonLiveTimingInMock;

if isMockTimingEscape
    return;
end

if RTConfig.Fs ~= 2400
    error('Live/mock-live Fs must be 2400 Hz.');
end
if RTConfig.ChunkSamples ~= round(RTConfig.ChunkSeconds * RTConfig.Fs)
    error('RTConfig.ChunkSamples must match round(ChunkSeconds * Fs).');
end
if RTConfig.PowerWindowSamples ~= round(RTConfig.PowerWindowSeconds * RTConfig.Fs)
    error('RTConfig.PowerWindowSamples must match round(PowerWindowSeconds * Fs).');
end
if RTConfig.BufferSamples ~= round(RTConfig.BufferSeconds * RTConfig.Fs)
    error('RTConfig.BufferSamples must match round(BufferSeconds * Fs).');
end
if RTConfig.ChunkSamples ~= 480
    error('0.2-second chunks at 2400 Hz must be 480 samples.');
end
if RTConfig.PowerWindowSamples ~= 4800
    error('2-second window at 2400 Hz must be 4800 samples.');
end
if RTConfig.BufferSamples < RTConfig.PowerWindowSamples
    error('BufferSamples must be at least PowerWindowSamples.');
end
if mod(RTConfig.PowerWindowSamples, RTConfig.ChunkSamples) ~= 0
    error('PowerWindowSamples must be an integer multiple of ChunkSamples.');
end
end

function local_check_fallback_fields(RTConfig)
% Validate technical fallback config fields without building a matrix.
if ~isfield(RTConfig.Spatial, 'Fallback') || ~isstruct(RTConfig.Spatial.Fallback)
    error('RTConfig.Spatial.Fallback must be a struct for technical fallback matrix sources.');
end
fallback = RTConfig.Spatial.Fallback;
local_require_field(fallback, {'Type'}, 'RTConfig.Spatial.Fallback.Type');
allowedFallbackTypes = {'single_channel','channel_average'};
if ~ismember(char(fallback.Type), allowedFallbackTypes)
    error('RTConfig.Spatial.Fallback.Type must be one of: %s.', strjoin(allowedFallbackTypes, ', '));
end
local_check_positive_integer(fallback.ChannelIndex, 'RTConfig.Spatial.Fallback.ChannelIndex');
local_check_scalar_logical(fallback.NormalizeWeights, 'RTConfig.Spatial.Fallback.NormalizeWeights');
local_check_scalar_logical(fallback.AllowIfNoIPSMatrix, 'RTConfig.Spatial.Fallback.AllowIfNoIPSMatrix');
end

function local_check_feedback_circle_fields(RTConfig)
% Validate local-circle display config without opening a display.
if ~isfield(RTConfig.Feedback, 'Circle') || ~isstruct(RTConfig.Feedback.Circle)
    error('RTConfig.Feedback.Circle must be a struct for live/mock-live configs.');
end
circle = RTConfig.Feedback.Circle;
requiredFields = {'Color','BackgroundColor','OuterCircleColor','ZMin','ZMax', ...
    'MinRadiusPx','MaxRadiusPx','UseAreaProportionalMapping','VisualAlpha', ...
    'ShowOuterCircle','ShowFixation','InstructionText','HideMeaningFromParticipant'};
for iField = 1:numel(requiredFields)
    fieldName = requiredFields{iField};
    local_require_field(circle, {fieldName}, ['RTConfig.Feedback.Circle.' fieldName]);
end
if ~isnumeric(circle.Color) || numel(circle.Color) ~= 3
    error('RTConfig.Feedback.Circle.Color must be an RGB triplet.');
end
if ~isnumeric(circle.BackgroundColor) || numel(circle.BackgroundColor) ~= 3
    error('RTConfig.Feedback.Circle.BackgroundColor must be an RGB triplet.');
end
if ~isnumeric(circle.OuterCircleColor) || numel(circle.OuterCircleColor) ~= 3
    error('RTConfig.Feedback.Circle.OuterCircleColor must be an RGB triplet.');
end
if ~isnumeric(circle.VisualAlpha) || ~isscalar(circle.VisualAlpha) || ...
        ~isfinite(circle.VisualAlpha) || circle.VisualAlpha < 0 || circle.VisualAlpha > 1
    error('RTConfig.Feedback.Circle.VisualAlpha must be in [0, 1].');
end
local_check_scalar_logical(circle.UseAreaProportionalMapping, ...
    'RTConfig.Feedback.Circle.UseAreaProportionalMapping');
local_check_scalar_logical(circle.ShowOuterCircle, 'RTConfig.Feedback.Circle.ShowOuterCircle');
local_check_scalar_logical(circle.ShowFixation, 'RTConfig.Feedback.Circle.ShowFixation');
local_check_scalar_logical(circle.HideMeaningFromParticipant, ...
    'RTConfig.Feedback.Circle.HideMeaningFromParticipant');
end

function local_check_mock_live_fields(RTConfig)
% Mock-live fields are config-only until the source adapter is implemented.
local_check_positive_integer(RTConfig.MockLive.RandomSeed, 'RTConfig.MockLive.RandomSeed');
local_check_scalar_logical(RTConfig.MockLive.UseDeterministicData, ...
    'RTConfig.MockLive.UseDeterministicData');
if ~(isempty(RTConfig.MockLive.FixturePath) || ischar(RTConfig.MockLive.FixturePath) || ...
        isstring(RTConfig.MockLive.FixturePath))
    error('RTConfig.MockLive.FixturePath must be empty, char, or string.');
end
end

function local_check_logging_fields(RTConfig)
% Logging behavior is declared here but not implemented in Step 3A-0a.
loggingFlags = {'SaveProjectedFilteredTrace','SaveRawChunksLocal','StoreTracesAsSingle'};
for iFlag = 1:numel(loggingFlags)
    fieldName = loggingFlags{iFlag};
    local_check_scalar_logical(RTConfig.Logging.(fieldName), ['RTConfig.Logging.' fieldName]);
end
local_check_positive_integer(RTConfig.Logging.FlushEveryNMeasures, ...
    'RTConfig.Logging.FlushEveryNMeasures');
allowedFormats = {'matfile','mat'};
if ~isfield(RTConfig.Logging, 'SaveFormat') || ...
        ~ismember(char(RTConfig.Logging.SaveFormat), allowedFormats)
    error('RTConfig.Logging.SaveFormat must be one of: %s.', strjoin(allowedFormats, ', '));
end
end

function local_check_live_dry_run_fields(RTConfig)
% Dry-run settings are validated as config only.
local_check_positive_numeric(RTConfig.LiveDryRun.TimeoutSecs, ...
    'RTConfig.LiveDryRun.TimeoutSecs');
local_check_positive_numeric(RTConfig.LiveDryRun.ExpectedFs, ...
    'RTConfig.LiveDryRun.ExpectedFs');
local_check_scalar_logical(RTConfig.LiveDryRun.RequireChannelLabels, ...
    'RTConfig.LiveDryRun.RequireChannelLabels');
local_check_scalar_logical(RTConfig.LiveDryRun.RequireSamplingRateMatch, ...
    'RTConfig.LiveDryRun.RequireSamplingRateMatch');
local_check_scalar_logical(RTConfig.LiveDryRun.RunDuringConfigCheck, ...
    'RTConfig.LiveDryRun.RunDuringConfigCheck');
local_check_positive_numeric(RTConfig.LiveDryRun.DurationSeconds, ...
    'RTConfig.LiveDryRun.DurationSeconds');
end

function local_check_safety_fields(RTConfig)
% Safety runtime helpers are not implemented here.
local_check_scalar_logical(RTConfig.Safety.EnableKeyboardStop, ...
    'RTConfig.Safety.EnableKeyboardStop');
local_check_scalar_logical(RTConfig.Safety.EnableStopFile, ...
    'RTConfig.Safety.EnableStopFile');
local_check_scalar_logical(RTConfig.Safety.UseMaxDurationFailsafe, ...
    'RTConfig.Safety.UseMaxDurationFailsafe');
local_check_positive_integer(RTConfig.Safety.MaxConsecutiveTimeouts, ...
    'RTConfig.Safety.MaxConsecutiveTimeouts');
local_check_scalar_string(RTConfig.Safety.StopKey, 'RTConfig.Safety.StopKey');
local_check_scalar_string(RTConfig.Safety.SecondaryStopKey, ...
    'RTConfig.Safety.SecondaryStopKey');
end

function local_require_field(S, path, label)
% Require a nested field without mutating the config.
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        error('%s is required.', label);
    end
    cursor = cursor.(fieldName);
end
end

function local_check_scalar_logical(value, label)
% Validate scalar logical flags.
if ~local_is_scalar_logical(value)
    error('%s must be a scalar logical.', label);
end
end

function tf = local_is_scalar_logical(value)
% Check logical scalar without throwing.
tf = islogical(value) && isscalar(value);
end

function local_check_positive_integer(value, label)
% Validate finite positive integer scalars.
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 1 || value ~= round(value)
    error('%s must be a positive integer scalar.', label);
end
end

function local_check_positive_numeric(value, label)
% Validate finite positive numeric scalars.
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('%s must be a finite positive numeric scalar.', label);
end
end

function local_check_scalar_string(value, label)
% Validate scalar text values while allowing char and string.
if ~(ischar(value) || (isstring(value) && isscalar(value)))
    error('%s must be char or scalar string.', label);
end
end

function local_check_optional_text(value, label)
% Validate optional text fields used for editable live paths/settings.
if isempty(value)
    return;
end
local_check_scalar_string(value, label);
end

function local_check_nonempty_text(value, label)
% Validate required live connection text fields.
local_check_scalar_string(value, label);
if isempty(strtrim(char(value)))
    error('%s must be nonempty when TestBufferFcn is empty.', label);
end
end

function local_check_cell_array(value, label)
% Validate cell-array audit fields without constraining their text content.
if ~iscell(value)
    error('%s must be a cell array.', label);
end
end

function local_check_setting_origin_fields(SettingOrigin)
% Validate provenance labels separately from runtime connection values.
requiredOrigins = {'Host','Port','BufferMPath','FieldTripRoot', ...
    'RequiredBufferRoot','UseBrainstormPluginPaths'};
allowedOrigins = {'config','benjamin_code','test_hook', ...
    'historical_unconfirmed','unresolved'};
for iOrigin = 1:numel(requiredOrigins)
    fieldName = requiredOrigins{iOrigin};
    local_require_field(SettingOrigin, {fieldName}, ...
        ['RTConfig.Source.FieldTrip.SettingOrigin.' fieldName]);
    local_check_nonempty_text(SettingOrigin.(fieldName), ...
        ['RTConfig.Source.FieldTrip.SettingOrigin.' fieldName]);
    if ~ismember(char(SettingOrigin.(fieldName)), allowedOrigins)
        error('Invalid setting origin label for %s.', fieldName);
    end
end
end

function RTConfig = local_fill_step1_defaults(RTConfig)
% Add Step 1 defaults without overwriting user-provided values.
if ~isfield(RTConfig, 'Validation') || isempty(RTConfig.Validation)
    RTConfig.Validation = struct();
end
if ~isfield(RTConfig, 'Brainstorm') || isempty(RTConfig.Brainstorm)
    RTConfig.Brainstorm = struct();
end
if ~isfield(RTConfig, 'Simulation') || isempty(RTConfig.Simulation)
    RTConfig.Simulation = struct();
end
if ~isfield(RTConfig, 'Baseline') || isempty(RTConfig.Baseline)
    RTConfig.Baseline = struct();
end
if ~isfield(RTConfig, 'Feedback') || isempty(RTConfig.Feedback)
    RTConfig.Feedback = struct();
end
if ~isfield(RTConfig, 'Analysis') || isempty(RTConfig.Analysis)
    RTConfig.Analysis = struct();
end
if ~isfield(RTConfig, 'SessionMetadata') || isempty(RTConfig.SessionMetadata)
    RTConfig.SessionMetadata = struct();
end

RTConfig = local_set_missing(RTConfig, {'Filter','EmpiricalDelaySamples'}, NaN);
RTConfig = local_set_missing(RTConfig, {'Filter','DelayCorrectionUsed'}, NaN);

RTConfig = local_set_missing(RTConfig, {'Simulation','EnableDroppedChunks'}, false);
RTConfig = local_set_missing(RTConfig, {'Simulation','DropProbability'}, 0);
RTConfig = local_set_missing(RTConfig, {'Simulation','DropChunkIndices'}, []);
RTConfig = local_set_missing(RTConfig, {'Simulation','RandomSeed'}, []);
RTConfig = local_set_missing(RTConfig, {'Simulation','EnableJitter'}, false);
RTConfig = local_set_missing(RTConfig, {'Simulation','MaxJitterSamples'}, 0);

RTConfig = local_set_missing(RTConfig, {'Baseline','MinValidWindows'}, 10);
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierMethod'}, 'percentile');
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierPercentileLow'}, 5);
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierPercentileHigh'}, 95);
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierZThreshold'}, 3);
RTConfig = local_set_missing(RTConfig, {'Baseline','RequireConfigHashMatch'}, true);
RTConfig = local_set_missing(RTConfig, {'Baseline','Path'}, '');

RTConfig = local_set_missing(RTConfig, {'Feedback','Mode'}, 'none');
RTConfig = local_set_missing(RTConfig, {'Feedback','UpdateEveryNValidMeasures'}, 1);
RTConfig = local_set_missing(RTConfig, {'Feedback','MapSource'}, 'ZSmoothed');
RTConfig = local_set_missing(RTConfig, {'Feedback','ClipRange'}, [-5 5]);

RTConfig = local_set_missing(RTConfig, {'Analysis','DisplayMode'}, 'off');
RTConfig = local_set_missing(RTConfig, {'Analysis','ReportRoot'}, fullfile('outputs', 'reports'));
RTConfig = local_set_missing(RTConfig, {'Analysis','SaveFigures'}, true);
RTConfig = local_set_missing(RTConfig, {'Analysis','SaveTables'}, true);
RTConfig = local_set_missing(RTConfig, {'Analysis','SaveMat'}, true);
RTConfig = local_set_missing(RTConfig, {'Analysis','FastMode'}, false);
RTConfig = local_set_missing(RTConfig, {'Analysis','MinThetaOnMinusOffZ'}, 0.5);
RTConfig = local_set_missing(RTConfig, {'Analysis','MaxWrongBandMeanZ'}, 1.0);

RTConfig = local_set_missing(RTConfig, {'SessionMetadata','RunID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','DatasetName'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','SubjectID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','SessionID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','TrialID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','StrategyLabel'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','ConditionLabel'}, '');

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','EnableFFTComparison'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','EnableIIRSOSComparison'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','WindowSamples'}, RTConfig.PowerWindowSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','StepSamples'}, RTConfig.ChunkSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','MinCyclesAtLowFreq'}, 3);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','ReferenceStrideMode'}, 'dense');
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','ReferenceStepSamples'}, RTConfig.ChunkSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','SaveDenseDebugReference'}, false);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','UseWelchIfAvailable'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','DemeanBeforeFFT'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','Taper'}, 'hann');
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','NFFT'}, []);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','ReferenceBands'}, [4 8; 8 12; 13 30]);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','BandDetection','Enable'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','BandDetection','SearchBand'}, [1 60]);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','BandDetection','ReferenceBands'}, [4 8; 8 12; 13 30; 30 59]);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','Controls','Enable'}, false);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','Brainstorm','Mode'}, 'auto');
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','Brainstorm','RequireForPass'}, false);

RTConfig = local_set_missing(RTConfig, {'Brainstorm','Path'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','Version'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','FilterSpecPath'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineFilteredPath'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineFilteredVariable'}, 'XBrainstorm');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineBandpassFunction'}, 'bst_bandpass_hfilter');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineBandpassMethod'}, 'bst-hfilter-2019');
end

function S = local_set_missing(S, path, value)
% Set a nested field only when it does not already exist.
if numel(path) == 1
    if ~isfield(S, path{1}) || isempty(S.(path{1}))
        S.(path{1}) = value;
    end
    return;
end

fieldName = path{1};
if ~isfield(S, fieldName) || isempty(S.(fieldName)) || ~isstruct(S.(fieldName))
    S.(fieldName) = struct();
end
S.(fieldName) = local_set_missing(S.(fieldName), path(2:end), value);
end

function stepSamples = local_resolve_reference_step_samples(RTConfig)
% Resolve stepped-reference stride with backward-compatible fallbacks.
stepSamples = [];
if isfield(RTConfig.Validation.Step1, 'ReferenceStepSamples') && ...
        local_is_positive_integer_scalar(RTConfig.Validation.Step1.ReferenceStepSamples)
    stepSamples = RTConfig.Validation.Step1.ReferenceStepSamples;
elseif isfield(RTConfig.Validation.Step1, 'StepSamples') && ...
        local_is_positive_integer_scalar(RTConfig.Validation.Step1.StepSamples)
    stepSamples = RTConfig.Validation.Step1.StepSamples;
elseif isfield(RTConfig, 'ChunkSamples') && local_is_positive_integer_scalar(RTConfig.ChunkSamples)
    stepSamples = RTConfig.ChunkSamples;
else
    stepSamples = 1;
end

stepSamples = round(stepSamples);
if stepSamples < 1
    error('RTConfig.Validation.Step1.ReferenceStepSamples must resolve to at least 1.');
end
end

function tf = local_is_positive_integer_scalar(x)
% Check positive integer scalar settings without throwing.
tf = isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && x == round(x);
end

function tf = local_is_empty_nan_or_finite_scalar(x)
% Validate optional scalar delay fields.
if isempty(x)
    tf = true;
elseif isnumeric(x) && isscalar(x) && (isnan(x) || isfinite(x))
    tf = true;
else
    tf = false;
end
end

function tf = local_is_scalar_logical_or_numeric_flag(x)
% Accept true/false or scalar numeric flags.
tf = (islogical(x) && isscalar(x)) || (isnumeric(x) && isscalar(x) && isfinite(x));
end
