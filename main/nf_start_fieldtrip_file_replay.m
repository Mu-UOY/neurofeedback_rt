function ReplayResult = nf_start_fieldtrip_file_replay(ReplayConfig)
% NF_START_FIELDTRIP_FILE_REPLAY Start blocking FieldTrip fileproxy replay.
%
% USAGE:  ReplayResult = nf_start_fieldtrip_file_replay(ReplayConfig)
%
% DESCRIPTION:
%     Producer-side utility for local development. It sends a recorded dataset
%     into a FieldTrip realtime buffer via ft_realtime_fileproxy and blocks
%     until that function returns. Run this in a separate MATLAB session from
%     the neurofeedback consumer.

%% ===== VALIDATE AND PREPARE =====
ReplayConfig = local_validate_replay_config(ReplayConfig);
PathInfo = local_add_fieldtrip_paths(ReplayConfig);
[fileProxyFcn, fileProxyPath] = local_resolve_fileproxy(ReplayConfig);
TargetURI = sprintf('buffer://%s:%d', char(ReplayConfig.Host), ReplayConfig.Port);
cfg = local_fileproxy_cfg(ReplayConfig, TargetURI);

%% ===== INITIALIZE RESULT =====
ReplayResult = struct();
ReplayResult.DatasetPath = ReplayConfig.DatasetPath;
ReplayResult.TargetURI = TargetURI;
ReplayResult.Host = ReplayConfig.Host;
ReplayResult.Port = ReplayConfig.Port;
ReplayResult.Speed = ReplayConfig.Speed;
ReplayResult.BlockSeconds = ReplayConfig.BlockSeconds;
ReplayResult.ReadEvents = ReplayConfig.ReadEvents;
ReplayResult.Channel = ReplayConfig.Channel;
ReplayResult.FileProxyFunction = fileProxyPath;
ReplayResult.StartedAt = local_now_text();
ReplayResult.Status = 'starting';
ReplayResult.Messages = {'ft_realtime_fileproxy is a blocking producer; run it in a separate MATLAB session.'};
ReplayResult.PathInfo = PathInfo;
ReplayResult.Cfg = cfg;

%% ===== START BLOCKING PRODUCER =====
% TestFileProxyFcn allows tests to inspect cfg without starting a server.
try
    if ~isempty(ReplayConfig.TestFileProxyFcn)
        ReplayResult.Status = 'test_hook_started';
        ReplayConfig.TestFileProxyFcn(cfg);
    else
        ReplayResult.Status = 'running';
        fileProxyFcn(cfg);
    end
    ReplayResult.Status = 'completed';
catch ME
    ReplayResult.Status = 'error';
    ReplayResult.Messages{end+1} = ME.message;
    rethrow(ME);
end

end

function ReplayConfig = local_validate_replay_config(ReplayConfig)
% Validate stable producer config fields.
required = {'DatasetPath','Host','Port','Speed','BlockSeconds','ReadEvents', ...
    'Channel','FieldTripRoot','TestFileProxyFcn'};
for iField = 1:numel(required)
    if ~isstruct(ReplayConfig) || ~isfield(ReplayConfig, required{iField})
        error('ReplayConfig.%s is required.', required{iField});
    end
end
ReplayConfig.DatasetPath = char(ReplayConfig.DatasetPath);
ReplayConfig.Host = char(ReplayConfig.Host);
if exist(ReplayConfig.DatasetPath, 'file') ~= 2 && exist(ReplayConfig.DatasetPath, 'dir') ~= 7
    error('ReplayConfig.DatasetPath does not exist: %s', ReplayConfig.DatasetPath);
end
if isempty(strtrim(ReplayConfig.Host))
    error('ReplayConfig.Host must be nonempty.');
end
if ~isnumeric(ReplayConfig.Port) || ~isscalar(ReplayConfig.Port) || ...
        ~isfinite(ReplayConfig.Port) || ReplayConfig.Port < 1 || ...
        ReplayConfig.Port > 65535 || ReplayConfig.Port ~= round(ReplayConfig.Port)
    error('ReplayConfig.Port must be a valid positive integer TCP port.');
end
if ~isnumeric(ReplayConfig.Speed) || ~isscalar(ReplayConfig.Speed) || ...
        ~isfinite(ReplayConfig.Speed) || ReplayConfig.Speed <= 0
    error('ReplayConfig.Speed must be a finite positive scalar.');
end
if ~isnumeric(ReplayConfig.BlockSeconds) || ~isscalar(ReplayConfig.BlockSeconds) || ...
        ~isfinite(ReplayConfig.BlockSeconds) || ReplayConfig.BlockSeconds <= 0
    error('ReplayConfig.BlockSeconds must be a finite positive scalar.');
end
if ~(islogical(ReplayConfig.ReadEvents) && isscalar(ReplayConfig.ReadEvents))
    error('ReplayConfig.ReadEvents must be a scalar logical.');
end
if ~isempty(ReplayConfig.TestFileProxyFcn) && ~isa(ReplayConfig.TestFileProxyFcn, 'function_handle')
    error('ReplayConfig.TestFileProxyFcn must be empty or a function_handle.');
end
end

function PathInfo = local_add_fieldtrip_paths(ReplayConfig)
% Add explicit FieldTrip folders without removing unrelated paths.
PathInfo = struct();
PathInfo.FieldTripRoot = char(ReplayConfig.FieldTripRoot);
PathInfo.AddedPaths = {};
PathInfo.ftVersion = '';
PathInfo.Messages = {};

if ~isempty(PathInfo.FieldTripRoot)
    if exist(PathInfo.FieldTripRoot, 'dir') ~= 7
        error('ReplayConfig.FieldTripRoot does not exist: %s', PathInfo.FieldTripRoot);
    end
    candidatePaths = {PathInfo.FieldTripRoot, ...
        fullfile(PathInfo.FieldTripRoot, 'realtime'), ...
        fullfile(PathInfo.FieldTripRoot, 'realtime', 'fileproxy'), ...
        fullfile(PathInfo.FieldTripRoot, 'fileio')};
    for iPath = 1:numel(candidatePaths)
        if exist(candidatePaths{iPath}, 'dir') == 7
            addpath(candidatePaths{iPath}, '-begin');
            PathInfo.AddedPaths{end+1} = candidatePaths{iPath}; %#ok<AGROW>
        end
    end
end

try
    if exist('ft_version', 'file') ~= 0 || exist('ft_version', 'builtin') ~= 0
        PathInfo.ftVersion = evalc('ft_version');
    end
catch ME
    PathInfo.Messages{end+1} = sprintf('ft_version unavailable: %s', ME.message);
end
end

function [fileProxyFcn, fileProxyPath] = local_resolve_fileproxy(ReplayConfig)
% Resolve the producer function, requiring FieldTrip only for real replay.
if ~isempty(ReplayConfig.TestFileProxyFcn)
    fileProxyFcn = ReplayConfig.TestFileProxyFcn;
    fileProxyPath = func2str(ReplayConfig.TestFileProxyFcn);
    return;
end

fileProxyPath = which('ft_realtime_fileproxy');
if isempty(fileProxyPath)
    error('ft_realtime_fileproxy was not found on the MATLAB path.');
end
fileProxyFcn = @ft_realtime_fileproxy;
end

function cfg = local_fileproxy_cfg(ReplayConfig, TargetURI)
% Build the common FieldTrip fileproxy cfg used by current versions.
cfg = struct();
cfg.dataset = ReplayConfig.DatasetPath;
cfg.target = struct();
cfg.target.datafile = TargetURI;
cfg.speed = ReplayConfig.Speed;
cfg.blocksize = ReplayConfig.BlockSeconds;
cfg.channel = ReplayConfig.Channel;
if ReplayConfig.ReadEvents
    cfg.readevent = 'yes';
else
    cfg.readevent = 'no';
end
end

function value = local_now_text()
% Return a stable timestamp string.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
else
    value = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
end
