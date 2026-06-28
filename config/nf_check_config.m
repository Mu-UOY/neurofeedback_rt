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
    'simulated_trial','live_fieldtrip','live_brainstorm'};
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

RTConfig = local_set_missing(RTConfig, {'Filter','EmpiricalDelaySamples'}, NaN);
RTConfig = local_set_missing(RTConfig, {'Filter','DelayCorrectionUsed'}, NaN);

RTConfig = local_set_missing(RTConfig, {'Simulation','EnableDroppedChunks'}, false);
RTConfig = local_set_missing(RTConfig, {'Simulation','DropProbability'}, 0);
RTConfig = local_set_missing(RTConfig, {'Simulation','DropChunkIndices'}, []);
RTConfig = local_set_missing(RTConfig, {'Simulation','RandomSeed'}, []);
RTConfig = local_set_missing(RTConfig, {'Simulation','EnableJitter'}, false);
RTConfig = local_set_missing(RTConfig, {'Simulation','MaxJitterSamples'}, 0);

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
