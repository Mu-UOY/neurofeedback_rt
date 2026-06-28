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
% Step 1 fields may be missing from configs saved before this layer existed.
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

allowedBrainstormModes = {'auto','skip','precomputed_filtered','bst_function','filter_spec','iir_self_test'};
if ~isfield(RTConfig.Validation.Step1.Brainstorm, 'Mode') || ...
        ~ismember(RTConfig.Validation.Step1.Brainstorm.Mode, allowedBrainstormModes)
    error('RTConfig.Validation.Step1.Brainstorm.Mode must be one of: %s.', ...
        strjoin(allowedBrainstormModes, ', '));
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

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','EnableFFTComparison'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','EnableIIRSOSComparison'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','WindowSamples'}, RTConfig.PowerWindowSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','StepSamples'}, RTConfig.ChunkSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','MinCyclesAtLowFreq'}, 3);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','UseWelchIfAvailable'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','DemeanBeforeFFT'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','Taper'}, 'hann');
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','NFFT'}, []);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','ReferenceBands'}, [4 8; 8 12; 13 30]);

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
