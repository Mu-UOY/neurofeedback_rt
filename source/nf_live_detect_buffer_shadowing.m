function ShadowInfo = nf_live_detect_buffer_shadowing(allBufferPaths, selectedBufferPath, RTConfig)
% NF_LIVE_DETECT_BUFFER_SHADOWING Validate selected buffer.m provenance.
%
% USAGE:  ShadowInfo = nf_live_detect_buffer_shadowing(allBufferPaths, selectedBufferPath, RTConfig)
%
% DESCRIPTION:
%     Checks whether MATLAB resolved buffer.m to an acceptable FieldTrip
%     realtime buffer path. MATLAB toolbox buffer detection uses only path
%     heuristics and is kept separate from configured root mismatches.

%% ===== INITIALIZE OUTPUT =====
allBufferPaths = local_cellstr(allBufferPaths);
selectedBufferPath = local_char(selectedBufferPath);

ShadowInfo = struct();
ShadowInfo.SelectedBufferPath = selectedBufferPath;
ShadowInfo.AllBufferPaths = allBufferPaths;
ShadowInfo.BufferFound = ~isempty(allBufferPaths) && ~isempty(selectedBufferPath);
ShadowInfo.BufferShadowingDetected = numel(allBufferPaths) > 1;
ShadowInfo.BufferLooksLikeMatlabToolbox = local_looks_like_matlab_toolbox(selectedBufferPath);
ShadowInfo.SelectedUnderFieldTripRoot = false;
ShadowInfo.SelectedUnderRequiredRoot = false;
ShadowInfo.Pass = true;
ShadowInfo.Messages = {};

%% ===== CHECK BUFFER PRESENCE =====
% A missing buffer is a path/config error, not an opportunity to guess paths.
if ~ShadowInfo.BufferFound
    ShadowInfo.Pass = false;
    ShadowInfo.Messages{end+1} = 'No buffer.m found on the MATLAB path.';
    return;
end

%% ===== CHECK MATLAB TOOLBOX SHADOWING =====
% Do not infer toolbox shadowing merely from being outside configured roots.
allowMatlabToolbox = local_get_logical(RTConfig, ...
    {'Source','FieldTrip','AllowMatlabToolboxBuffer'}, false);
if ShadowInfo.BufferLooksLikeMatlabToolbox && ~allowMatlabToolbox
    ShadowInfo.Pass = false;
    ShadowInfo.Messages{end+1} = ...
        'MATLAB toolbox buffer.m appears to be selected instead of FieldTrip realtime buffer.';
end

%% ===== CHECK CONFIGURED ROOTS =====
% FieldTripRoot mismatch is diagnostic; RequiredBufferRoot mismatch is fatal.
fieldTripRoot = local_get_text(RTConfig, {'Source','FieldTrip','FieldTripRoot'}, '');
if ~isempty(fieldTripRoot)
    ShadowInfo.SelectedUnderFieldTripRoot = local_is_under_root(selectedBufferPath, fieldTripRoot);
    if ~ShadowInfo.SelectedUnderFieldTripRoot
        ShadowInfo.Messages{end+1} = ...
            'Selected buffer.m is outside configured FieldTripRoot.';
    end
end

requiredRoot = local_get_text(RTConfig, {'Source','FieldTrip','RequiredBufferRoot'}, '');
if ~isempty(requiredRoot)
    ShadowInfo.SelectedUnderRequiredRoot = local_is_under_root(selectedBufferPath, requiredRoot);
    if ~ShadowInfo.SelectedUnderRequiredRoot
        ShadowInfo.Pass = false;
        ShadowInfo.Messages{end+1} = ...
            'Selected buffer.m is outside RequiredBufferRoot.';
    end
end

end

function paths = local_cellstr(paths)
% Normalize which('-all') output for stable downstream checks.
if isempty(paths)
    paths = {};
elseif ischar(paths) || isstring(paths)
    paths = cellstr(paths);
elseif ~iscell(paths)
    paths = {};
end
end

function value = local_char(value)
% Convert scalar text to char, preserving empty values.
if isempty(value)
    value = '';
elseif isstring(value)
    value = char(value);
end
end

function tf = local_looks_like_matlab_toolbox(pathValue)
% Detect the common Signal Processing Toolbox buffer.m path patterns.
pathValue = strrep(lower(local_char(pathValue)), '\', '/');
tf = contains(pathValue, 'toolbox/signal') || contains(pathValue, 'sigtools');
end

function tf = local_is_under_root(pathValue, rootValue)
% Check path ancestry using normalized separators without resolving symlinks.
pathValue = strrep(lower(local_char(pathValue)), '\', '/');
rootValue = strrep(lower(local_char(rootValue)), '\', '/');
pathValue = regexprep(pathValue, '/+$', '');
rootValue = regexprep(rootValue, '/+$', '');
tf = strcmp(pathValue, rootValue) || startsWith(pathValue, [rootValue '/']);
end

function value = local_get_text(S, path, defaultValue)
% Read optional nested text field.
value = local_get_nested(S, path, defaultValue);
if isstring(value)
    value = char(value);
end
end

function value = local_get_logical(S, path, defaultValue)
% Read optional nested logical field.
value = local_get_nested(S, path, defaultValue);
if ~(islogical(value) && isscalar(value))
    value = defaultValue;
end
end

function value = local_get_nested(S, path, defaultValue)
% Read nested struct fields without throwing.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
value = cursor;
end
