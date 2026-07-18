function Logger = nf_logger_init(RTConfig, phase, Source)
% NF_LOGGER_INIT Initialize a Step 3 logging scaffold.
%
% USAGE:  Logger = nf_logger_init(RTConfig, phase, Source)

%% ===== PARSE INPUTS =====
% Source is optional because logging can be initialized before live hardware.
if nargin < 2 || isempty(phase)
    phase = 'session';
end
if nargin < 3 || isempty(Source)
    Source = struct();
end
phase = char(phase);
local_check_phase(phase);

%% ===== CREATE SESSION TREE =====
% Session owns all files created by this logger instance.
if isfield(RTConfig, 'Logging') && isfield(RTConfig.Logging, 'ExistingSession') && ...
        isstruct(RTConfig.Logging.ExistingSession) && ...
        isfield(RTConfig.Logging.ExistingSession, 'SessionDir')
    Session = RTConfig.Logging.ExistingSession;
else
    Session = nf_make_session_output_dir(RTConfig, phase);
end
createdAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
SourceSummary = local_source_summary(Source, RTConfig);

%% ===== INITIALIZE LOGGER STRUCT =====
% Store paths up front so failed runs are easy to inspect.
Logger = struct();
Logger.Session = Session;
Logger.Phase = phase;
Logger.CreatedAt = createdAt;
Logger.ClosedAt = '';
Logger.Closed = false;
Logger.Partial = true;
Logger.Finalized = false;
Logger.RTConfig = RTConfig;
Logger.SourceSummary = SourceSummary;
Logger.ChunkMeta = struct([]);
Logger.Measures = struct([]);
Logger.NChunks = 0;
Logger.NMeasures = 0;
Logger.Messages = {};
Logger.PartialLogPaths = {};
Logger.LastPartialSavePath = '';
Logger.LastPartialSavedChunkIndex = 0;
Logger.LastPartialSavedMeasureIndex = 0;
Logger.FinalLogPath = '';
Logger.MeasureTablePath = '';
Logger.ChunkMetaPath = '';
Logger.SessionSummaryPath = '';
Logger.ConfigPath = fullfile(Session.ConfigDir, 'rt_config.mat');
Logger.SourcePath = fullfile(Session.SourceDir, 'source_summary.mat');

%% ===== SAVE STATIC METADATA =====
% Config and source summary are saved once at logger initialization.
SavedAt = createdAt; %#ok<NASGU>
save(Logger.ConfigPath, 'RTConfig', 'SavedAt');
save(Logger.SourcePath, 'SourceSummary', 'SavedAt');

if isfield(RTConfig, 'Logging') && isfield(RTConfig.Logging, 'SaveRawChunksLocal') && ...
        RTConfig.Logging.SaveRawChunksLocal
    Logger.Messages{end + 1} = ...
        'Raw chunk saving is deferred in Step 3A-0d and is not implemented.';
end
if isfield(RTConfig, 'Logging') && isfield(RTConfig.Logging, 'SaveProjectedFilteredTrace') && ...
        RTConfig.Logging.SaveProjectedFilteredTrace
    Logger.Messages{end + 1} = ...
        'Projected/filtered trace saving is deferred in Step 3A-0d.';
end

end

function local_check_phase(phase)
% Accept only the local Step 3A-0d phase labels.
allowed = {'live_self_test','live_resting','live_trial','live_rt_dry_run', ...
    'live_chunk_smoke_test','mock_live_test','resting','trial','test','session', ...
    'development_full_chain'};
if ~ismember(phase, allowed)
    error('Unknown logger phase: %s', phase);
end
end

function Summary = local_source_summary(Source, RTConfig)
% Build a stable source summary without touching live hardware.
Summary = struct();
Summary.Mode = local_text(Source, 'Mode', local_nested_text(RTConfig, {'Source','Mode'}, ''));
Summary.LiveAdapter = local_text(Source, 'LiveAdapter', ...
    local_nested_text(RTConfig, {'Source','LiveAdapter'}, ''));
Summary.Fs = local_numeric(Source, 'Fs', local_get_nested(RTConfig, {'Fs'}, NaN));
Summary.NChannels = local_numeric(Source, 'NChannels', local_nchannels(Source));
Summary.ChannelNames = local_cell(Source, 'ChannelNames');
Summary.ChannelNamesAfterCorrection = local_cell(Source, 'ChannelNamesAfterCorrection');
Summary.HeaderHash = local_text(Source, 'HeaderHash', '');
Summary.CorrectionState = local_struct(Source, 'CorrectionState');
Summary.InitialSample = local_numeric(Source, 'InitialSample', ...
    local_numeric(Source, 'StartSample', NaN));
Summary.LastSampleRead = local_numeric(Source, 'LastSampleRead', ...
    local_numeric(Source, 'CurrentSample', NaN));
Summary.IsLive = contains(char(Summary.Mode), 'live');
end

function value = local_text(S, fieldName, defaultValue)
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    value = char(S.(fieldName));
end
end

function value = local_numeric(S, fieldName, defaultValue)
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && isnumeric(S.(fieldName)) && ...
        ~isempty(S.(fieldName))
    value = double(S.(fieldName)(1));
end
end

function value = local_cell(S, fieldName)
value = {};
if isstruct(S) && isfield(S, fieldName) && iscell(S.(fieldName))
    value = S.(fieldName);
end
end

function value = local_struct(S, fieldName)
value = struct();
if isstruct(S) && isfield(S, fieldName) && isstruct(S.(fieldName))
    value = S.(fieldName);
end
end

function nChannels = local_nchannels(Source)
nChannels = NaN;
if isstruct(Source) && isfield(Source, 'ChannelNames') && iscell(Source.ChannelNames)
    nChannels = numel(Source.ChannelNames);
elseif isstruct(Source) && isfield(Source, 'Data') && isnumeric(Source.Data)
    nChannels = size(Source.Data, 1);
end
end

function value = local_nested_text(S, path, defaultValue)
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if ischar(current) || isstring(current)
    value = char(current);
end
end

function value = local_get_nested(S, path, defaultValue)
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
value = current;
end
