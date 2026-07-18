function [RTConfig, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath, RTConfig, varargin)
% NF_LOCAL_FIELDTRIP_REPLAY_CONFIG Configure local FieldTrip file replay.
%
% USAGE:  [RTConfig, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath)
%         [RTConfig, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath, RTConfig, ...)
%
% DESCRIPTION:
%     Configures only the live FieldTrip endpoint/source fields needed for a
%     local ft_realtime_fileproxy producer. Processing, spatial, correction,
%     feedback, safety, baseline, and protocol settings are preserved.

%% ===== PARSE INPUTS =====
if nargin < 1 || isempty(datasetPath)
    error('datasetPath is required for local FieldTrip replay.');
end
if nargin < 2 || isempty(RTConfig)
    RTConfig = nf_live_config();
end

Options = local_default_options(RTConfig);
Options = local_parse_name_values(Options, varargin{:});
datasetPath = char(datasetPath);
local_validate_dataset_path(datasetPath);
local_validate_options(Options);

%% ===== CONFIGURE CONSUMER ENDPOINT =====
Modes = nf_modes();
RTConfig.Source.Mode = Modes.Source.LiveFieldTrip;
RTConfig.Source.LiveAdapter = Modes.LiveAdapter.BenFieldTrip;
RTConfig.Source.FieldTrip.Host = Options.Host;
RTConfig.Source.FieldTrip.Port = Options.Port;
RTConfig.Source.FieldTrip.StreamRole = Modes.StreamRole.LocalReplay;
RTConfig.Source.FieldTrip.SettingOrigin.Host = Modes.SettingOrigin.CallerOverride;
RTConfig.Source.FieldTrip.SettingOrigin.Port = Modes.SettingOrigin.CallerOverride;

%% ===== BUILD PRODUCER CONFIG =====
ReplayConfig = struct();
ReplayConfig.DatasetPath = datasetPath;
ReplayConfig.Host = Options.Host;
ReplayConfig.Port = Options.Port;
ReplayConfig.Speed = Options.Speed;
ReplayConfig.BlockSeconds = Options.BlockSeconds;
ReplayConfig.ReadEvents = Options.ReadEvents;
ReplayConfig.Channel = Options.Channel;
ReplayConfig.FieldTripRoot = Options.FieldTripRoot;
ReplayConfig.TestFileProxyFcn = Options.TestFileProxyFcn;
ReplayConfig.Messages = {['Local replay config uses live_fieldtrip consumer path. ', ...
    'Transport-only fallback requires explicit operator overrides and does not prove IPS neurofeedback.']};

end

function Options = local_default_options(RTConfig)
% Default producer settings mirror the live chunk cadence.
Options = struct();
Options.Host = 'localhost';
Options.Port = 1900 + 72;
Options.Speed = 1;
Options.BlockSeconds = RTConfig.ChunkSeconds;
Options.ReadEvents = true;
Options.Channel = 'all';
Options.FieldTripRoot = local_get_nested_text(RTConfig, {'Source','FieldTrip','FieldTripRoot'}, '');
Options.TestFileProxyFcn = [];
end

function Options = local_parse_name_values(Options, varargin)
% Apply simple name/value overrides.
if mod(numel(varargin), 2) ~= 0
    error('Optional replay settings must be name/value pairs.');
end
for iArg = 1:2:numel(varargin)
    name = char(varargin{iArg});
    if ~isfield(Options, name)
        error('Unknown replay option: %s', name);
    end
    Options.(name) = varargin{iArg + 1};
end
end

function local_validate_dataset_path(datasetPath)
% Accept files and CTF .ds directories.
if isempty(strtrim(datasetPath))
    error('Replay DatasetPath must be nonempty.');
end
if exist(datasetPath, 'file') ~= 2 && exist(datasetPath, 'dir') ~= 7
    error('Replay dataset path does not exist as a file or directory: %s', datasetPath);
end
end

function local_validate_options(Options)
% Validate producer-only settings.
if ~(ischar(Options.Host) || (isstring(Options.Host) && isscalar(Options.Host))) || ...
        isempty(strtrim(char(Options.Host)))
    error('Replay Host must be nonempty text.');
end
if ~isnumeric(Options.Port) || ~isscalar(Options.Port) || ~isfinite(Options.Port) || ...
        Options.Port < 1 || Options.Port > 65535 || Options.Port ~= round(Options.Port)
    error('Replay Port must be a valid positive integer TCP port.');
end
if ~isnumeric(Options.Speed) || ~isscalar(Options.Speed) || ~isfinite(Options.Speed) || Options.Speed <= 0
    error('Replay Speed must be a finite positive scalar.');
end
if ~isnumeric(Options.BlockSeconds) || ~isscalar(Options.BlockSeconds) || ...
        ~isfinite(Options.BlockSeconds) || Options.BlockSeconds <= 0
    error('Replay BlockSeconds must be a finite positive scalar.');
end
if ~(islogical(Options.ReadEvents) && isscalar(Options.ReadEvents))
    error('Replay ReadEvents must be a scalar logical.');
end
if ~(ischar(Options.Channel) || iscell(Options.Channel) || isstring(Options.Channel))
    error('Replay Channel must be ''all'', a string array, or a cell array of labels/indices.');
end
if ~(isempty(Options.FieldTripRoot) || ischar(Options.FieldTripRoot) || ...
        (isstring(Options.FieldTripRoot) && isscalar(Options.FieldTripRoot)))
    error('Replay FieldTripRoot must be empty or text.');
end
if ~isempty(Options.TestFileProxyFcn) && ~isa(Options.TestFileProxyFcn, 'function_handle')
    error('Replay TestFileProxyFcn must be empty or a function_handle.');
end
end

function value = local_get_nested_text(S, path, defaultValue)
% Read optional nested text.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if ischar(cursor) || (isstring(cursor) && isscalar(cursor))
    value = char(cursor);
end
end
