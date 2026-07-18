function PathInfo = nf_live_add_fieldtrip_paths(RTConfig)
% NF_LIVE_ADD_FIELDTRIP_PATHS Add configured FieldTrip realtime paths.
%
% USAGE:  PathInfo = nf_live_add_fieldtrip_paths(RTConfig)
%
% DESCRIPTION:
%     Adds only explicitly configured FieldTrip realtime buffer paths and
%     validates that MATLAB resolves buffer.m to an acceptable candidate.

%% ===== INITIALIZE OUTPUT =====
PathInfo = struct();
PathInfo.Status = 'FAIL';
PathInfo.BufferFound = false;
PathInfo.SelectedBufferPath = '';
PathInfo.AllBufferPaths = {};
PathInfo.AddedPaths = {};
PathInfo.UsedTestHook = false;
PathInfo.BufferShadowingDetected = false;
PathInfo.BufferLooksLikeMatlabToolbox = false;
PathInfo.FieldTripRoot = '';
PathInfo.FieldTripVersion = '';
PathInfo.FtRealtimeFileProxyExists = false;
PathInfo.FtRealtimeFileProxyPath = '';
PathInfo.StreamRole = 'unknown';
PathInfo.Messages = {};

FT = RTConfig.Source.FieldTrip;
PathInfo.FieldTripRoot = FT.FieldTripRoot;
PathInfo.StreamRole = local_field(FT, 'StreamRole', 'unknown');

%% ===== TEST HOOK SHORT-CIRCUIT =====
% Hardware-free tests do not require a real buffer.m on the MATLAB path.
if isfield(FT, 'TestBufferFcn') && ~isempty(FT.TestBufferFcn)
    PathInfo.Status = 'PASS';
    PathInfo.UsedTestHook = true;
    PathInfo = local_attach_fieldtrip_capabilities(PathInfo);
    PathInfo.Messages{end+1} = 'Using RTConfig.Source.FieldTrip.TestBufferFcn; real buffer.m not required.';
    return;
end

%% ===== REQUIRE EXPLICIT PATH SOURCE =====
% Do not silently accept whichever buffer.m happens to be on the path.
if isempty(FT.BufferMPath) && isempty(FT.FieldTripRoot) && ...
        ~FT.AllowAlreadyOnPathBuffer
    error(['FieldTrip realtime buffer.m not found. Set RTConfig.Source.FieldTrip.BufferMPath ', ...
        'or RTConfig.Source.FieldTrip.FieldTripRoot in nf_live_config.m. ', ...
        'Do not rely on guessed Brainstorm paths.']);
end

%% ===== ADD EXPLICIT BUFFER FILE PARENT =====
% BufferMPath is the full path to buffer.m; add only its parent folder.
if ~isempty(FT.BufferMPath)
    bufferPath = char(FT.BufferMPath);
    if exist(bufferPath, 'file') ~= 2
        error('Configured RTConfig.Source.FieldTrip.BufferMPath does not exist: %s', bufferPath);
    end
    [bufferFolder, bufferName, bufferExt] = fileparts(bufferPath);
    if ~strcmpi([bufferName bufferExt], 'buffer.m')
        error('RTConfig.Source.FieldTrip.BufferMPath must point to buffer.m.');
    end
    addpath(bufferFolder, '-begin');
    PathInfo.AddedPaths{end+1} = bufferFolder;
end

%% ===== ADD CONFIGURED FIELDTRIP SUBFOLDERS =====
% Only the known realtime/fileio subfolders are considered.
if ~isempty(FT.FieldTripRoot)
    fieldTripRoot = char(FT.FieldTripRoot);
    if exist(fieldTripRoot, 'dir') ~= 7
        error('Configured RTConfig.Source.FieldTrip.FieldTripRoot does not exist: %s', fieldTripRoot);
    end
    candidatePaths = { ...
        fieldTripRoot, ...
        fullfile(fieldTripRoot, 'realtime'), ...
        fullfile(fieldTripRoot, 'realtime', 'buffer', 'matlab'), ...
        fullfile(fieldTripRoot, 'fileio')};
    for iPath = 1:numel(candidatePaths)
        if exist(candidatePaths{iPath}, 'dir') == 7
            addpath(candidatePaths{iPath}, '-begin');
            PathInfo.AddedPaths{end+1} = candidatePaths{iPath};
        end
    end
end

%% ===== VALIDATE SELECTED BUFFER =====
% The selected function must pass top-level shadowing/root checks.
allBuffers = which('buffer', '-all');
selectedBuffer = which('buffer');
ShadowInfo = nf_live_detect_buffer_shadowing(allBuffers, selectedBuffer, RTConfig);

PathInfo.BufferFound = ShadowInfo.BufferFound;
PathInfo.SelectedBufferPath = ShadowInfo.SelectedBufferPath;
PathInfo.AllBufferPaths = ShadowInfo.AllBufferPaths;
PathInfo.BufferShadowingDetected = ShadowInfo.BufferShadowingDetected;
PathInfo.BufferLooksLikeMatlabToolbox = ShadowInfo.BufferLooksLikeMatlabToolbox;
PathInfo.Messages = [PathInfo.Messages, ShadowInfo.Messages];

if ~ShadowInfo.BufferFound
    error(['FieldTrip realtime buffer.m not found. Set RTConfig.Source.FieldTrip.BufferMPath ', ...
        'or RTConfig.Source.FieldTrip.FieldTripRoot in nf_live_config.m. ', ...
        'Do not rely on guessed Brainstorm paths.']);
end
if ~ShadowInfo.Pass
    error('Invalid FieldTrip buffer.m selection: %s', strjoin(ShadowInfo.Messages, ' '));
end

PathInfo = local_attach_fieldtrip_capabilities(PathInfo);
PathInfo.Status = 'PASS';

end

function PathInfo = local_attach_fieldtrip_capabilities(PathInfo)
% Record optional FieldTrip capabilities without making them consumer gates.
proxyPath = which('ft_realtime_fileproxy');
PathInfo.FtRealtimeFileProxyExists = ~isempty(proxyPath);
PathInfo.FtRealtimeFileProxyPath = proxyPath;
try
    if exist('ft_version', 'file') ~= 0 || exist('ft_version', 'builtin') ~= 0
        PathInfo.FieldTripVersion = strtrim(evalc('ft_version'));
    end
catch ME
    PathInfo.Messages{end+1} = sprintf('ft_version unavailable: %s', ME.message);
end
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
