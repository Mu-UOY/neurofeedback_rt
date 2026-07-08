function Spatial = nf_prepare_live_combined_matrix(Source, RTConfig)
% NF_PREPARE_LIVE_COMBINED_MATRIX Prepare the live CombinedMatrix contract.
%
% USAGE:  Spatial = nf_prepare_live_combined_matrix(Source, RTConfig)
%
% DESCRIPTION:
%     Builds or loads the spatial CombinedMatrix used by the Step 3C live RT
%     dry run, then validates it against the corrected live channel header.

%% ===== INITIALIZE OUTPUT =====
% Keep the schema stable for saved dry-run reports and later revalidation.
Spatial = local_empty_spatial();

%% ===== CHECK MATRIX SOURCE =====
% Step 3C supports precomputed matrices and explicit technical fallbacks.
Modes = nf_modes();
matrixSource = local_get_text(RTConfig, {'Spatial','MatrixSource'}, '');
Spatial.MatrixSource = matrixSource;

switch matrixSource
    case Modes.Spatial.MatrixSource.ComputeLive
        error('ComputeLive spatial matrix preparation is not implemented in Step 3C.');

    case {Modes.Spatial.MatrixSource.TechnicalFallback, ...
            Modes.Spatial.MatrixSource.TechnicalPlaceholder}
        Spatial = local_prepare_technical_fallback(Spatial, Source, RTConfig, Modes);

    case Modes.Spatial.MatrixSource.Precomputed
        Spatial = local_prepare_precomputed(Spatial, Source, RTConfig);

    otherwise
        error('Unsupported live spatial MatrixSource: %s', matrixSource);
end

%% ===== REVALIDATE AGAINST LIVE HEADER =====
% Revalidation catches channel-count/order and correction-state mismatches.
Spatial = nf_revalidate_live_spatial_against_source(Spatial, Source, RTConfig);

end

function Spatial = local_empty_spatial()
% Return the required live spatial schema.
Spatial = struct();
Spatial.CombinedMatrix = [];
Spatial.InputChannelNames = {};
Spatial.OutputSignalNames = {};
Spatial.Hash = '';
Spatial.MatrixSource = '';
Spatial.ValidatedAgainstLiveHeader = false;
Spatial.CorrectionState = struct();
Spatial.LiveHeaderHash = '';
Spatial.IsIPS = false;
Spatial.IsTechnicalFallback = false;
Spatial.Messages = {};
end

function Spatial = local_prepare_technical_fallback(Spatial, Source, RTConfig, Modes)
% Build a deterministic one-signal technical matrix.
[channelNames, nChannels] = local_source_channel_names(Source);
fallbackType = local_get_text(RTConfig, {'Spatial','Fallback','Type'}, 'single_channel');

switch fallbackType
    case 'single_channel'
        selected = local_single_channel_index(channelNames, RTConfig);

    case 'channel_average'
        selected = local_channel_average_indices(channelNames, RTConfig);

    otherwise
        error('Unsupported live technical fallback type: %s', fallbackType);
end

matrix = zeros(1, nChannels);
matrix(selected) = 1 ./ numel(selected);
if local_get_logical(RTConfig, {'Spatial','Fallback','NormalizeWeights'}, true)
    weightSum = sum(matrix(selected));
    if weightSum ~= 0
        matrix(selected) = matrix(selected) ./ weightSum;
    end
end

Spatial.CombinedMatrix = matrix;
Spatial.InputChannelNames = channelNames;
if strcmp(Spatial.MatrixSource, Modes.Spatial.MatrixSource.TechnicalPlaceholder)
    Spatial.OutputSignalNames = {'technical_placeholder_signal'};
else
    Spatial.OutputSignalNames = {'technical_fallback_signal'};
end
Spatial.Hash = local_matrix_hash(matrix);
Spatial.ValidatedAgainstLiveHeader = true;
Spatial.CorrectionState = local_field(Source, 'CorrectionState', struct());
Spatial.LiveHeaderHash = local_text_field(Source, 'HeaderHash', '');
Spatial.IsIPS = false;
Spatial.IsTechnicalFallback = true;
Spatial.Messages = {'Technical fallback matrix used; do not claim IPS neurofeedback.'};
end

function Spatial = local_prepare_precomputed(Spatial, Source, RTConfig)
% Load a supported MAT schema and attach conservative metadata.
matrixPath = local_get_text(RTConfig, {'Spatial','CombinedMatrixPath'}, '');
if isempty(matrixPath) || exist(matrixPath, 'file') ~= 2
    error('Spatial.CombinedMatrixPath does not point to an existing file.');
end

loaded = load(matrixPath);
[matrix, meta] = local_extract_precomputed_matrix(loaded);
matrix = local_validate_matrix(matrix);

Spatial.CombinedMatrix = matrix;
Spatial.InputChannelNames = local_meta_cellstr(meta, 'InputChannelNames', {});
Spatial.OutputSignalNames = local_meta_cellstr(meta, 'OutputSignalNames', {});
Spatial.Hash = local_meta_text(meta, 'Hash', '');
Spatial.MatrixSource = local_get_text(RTConfig, {'Spatial','MatrixSource'}, '');
Spatial.CorrectionState = local_meta_struct(meta, 'CorrectionState', local_field(Source, 'CorrectionState', struct()));
Spatial.LiveHeaderHash = local_meta_text(meta, 'LiveHeaderHash', local_text_field(Source, 'HeaderHash', ''));
Spatial.IsIPS = local_meta_logical(meta, 'IsIPS', false);
Spatial.IsTechnicalFallback = false;
Spatial.Messages = local_meta_cellstr(meta, 'Messages', {});

if isempty(Spatial.Hash)
    Spatial.Hash = local_matrix_hash(matrix);
end
if isempty(Spatial.InputChannelNames)
    Spatial.InputChannelNames = local_source_channel_names(Source);
    Spatial.Messages{end+1} = 'Precomputed matrix did not include InputChannelNames; live header order was used for validation.';
end
if isempty(Spatial.OutputSignalNames)
    Spatial.OutputSignalNames = local_default_signal_names(size(matrix, 1));
end
end

function [matrix, meta] = local_extract_precomputed_matrix(loaded)
% Support the accepted MAT schemas.
meta = struct();
if isfield(loaded, 'Spatial') && isstruct(loaded.Spatial) && ...
        isfield(loaded.Spatial, 'CombinedMatrix')
    meta = loaded.Spatial;
    matrix = loaded.Spatial.CombinedMatrix;
elseif isfield(loaded, 'CombinedMatrix')
    meta = loaded;
    matrix = loaded.CombinedMatrix;
elseif isfield(loaded, 'Matrix')
    meta = loaded;
    matrix = loaded.Matrix;
else
    error('Precomputed spatial MAT file must contain Spatial.CombinedMatrix, CombinedMatrix, or Matrix.');
end
end

function matrix = local_validate_matrix(matrix)
% Validate numeric finite 2-D matrix content.
if ~isnumeric(matrix) || ndims(matrix) ~= 2 || isempty(matrix)
    error('CombinedMatrix must be a nonempty numeric 2-D matrix.');
end
matrix = double(matrix);
if any(~isfinite(matrix(:)))
    error('CombinedMatrix must contain only finite values.');
end
end

function idx = local_single_channel_index(channelNames, RTConfig)
% Select a single channel by explicit name or index.
channelName = local_get_text(RTConfig, {'Spatial','Fallback','ChannelName'}, '');
if ~isempty(channelName)
    match = find(strcmp(channelNames, channelName), 1, 'first');
    if isempty(match)
        error('Technical fallback channel name not found in live header: %s', channelName);
    end
    idx = match;
    return;
end

idx = local_get_numeric(RTConfig, {'Spatial','Fallback','ChannelIndex'}, NaN);
if ~isscalar(idx) || ~isfinite(idx) || idx < 1 || idx > numel(channelNames) || idx ~= round(idx)
    error('Technical fallback ChannelIndex must be a valid live channel index.');
end
idx = round(idx);
end

function idx = local_channel_average_indices(channelNames, RTConfig)
% Select named channels for averaging, or all channels when none are listed.
requestedNames = local_get_cellstr(RTConfig, {'Spatial','Fallback','ChannelNames'}, {});
if isempty(requestedNames)
    idx = 1:numel(channelNames);
    return;
end

idx = NaN(1, numel(requestedNames));
for iName = 1:numel(requestedNames)
    match = find(strcmp(channelNames, requestedNames{iName}), 1, 'first');
    if isempty(match)
        error('Technical fallback channel name not found in live header: %s', requestedNames{iName});
    end
    idx(iName) = match;
end
end

function [channelNames, nChannels] = local_source_channel_names(Source)
% Prefer corrected live channel labels, then raw labels, then generated names.
channelNames = {};
if isstruct(Source) && isfield(Source, 'ChannelNamesAfterCorrection') && ...
        ~isempty(Source.ChannelNamesAfterCorrection)
    channelNames = local_cellstr(Source.ChannelNamesAfterCorrection);
elseif isstruct(Source) && isfield(Source, 'ChannelNames') && ~isempty(Source.ChannelNames)
    channelNames = local_cellstr(Source.ChannelNames);
end

if isempty(channelNames)
    nChannels = local_numeric_field(Source, 'NChannels', NaN);
    if ~isscalar(nChannels) || ~isfinite(nChannels) || nChannels < 1 || nChannels ~= round(nChannels)
        error('Cannot determine corrected live channel count for spatial preparation.');
    end
    channelNames = local_default_channel_names(round(nChannels));
else
    nChannels = numel(channelNames);
end
end

function names = local_default_channel_names(nChannels)
% Generate deterministic channel labels when the source has no names.
names = cell(1, nChannels);
for iChannel = 1:nChannels
    names{iChannel} = sprintf('CH%03d', iChannel);
end
end

function names = local_default_signal_names(nSignals)
% Generate deterministic output signal names.
names = cell(1, nSignals);
for iSignal = 1:nSignals
    names{iSignal} = sprintf('signal_%03d', iSignal);
end
end

function hashValue = local_matrix_hash(matrix)
% Create a compact deterministic matrix fingerprint.
hashValue = sprintf('matrix_%dx%d_sum_%.17g', size(matrix, 1), size(matrix, 2), sum(matrix(:)));
end

function value = local_meta_text(S, fieldName, defaultValue)
% Read optional metadata text.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName)) && ...
        (ischar(S.(fieldName)) || isstring(S.(fieldName)))
    value = char(S.(fieldName));
end
end

function value = local_meta_logical(S, fieldName, defaultValue)
% Read optional metadata logical.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    raw = S.(fieldName);
    if islogical(raw) && isscalar(raw)
        value = raw;
    elseif isnumeric(raw) && isscalar(raw) && isfinite(raw)
        value = raw ~= 0;
    end
end
end

function value = local_meta_struct(S, fieldName, defaultValue)
% Read optional metadata struct.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && isstruct(S.(fieldName))
    value = S.(fieldName);
end
end

function value = local_meta_cellstr(S, fieldName, defaultValue)
% Read optional metadata cellstr.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName)
    value = local_cellstr(S.(fieldName));
end
end

function value = local_get_text(S, path, defaultValue)
% Read optional nested text field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if isempty(cursor)
    value = '';
elseif ischar(cursor) || isstring(cursor)
    value = char(cursor);
end
end

function value = local_get_logical(S, path, defaultValue)
% Read optional nested logical field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if islogical(cursor) && isscalar(cursor)
    value = cursor;
end
end

function value = local_get_numeric(S, path, defaultValue)
% Read optional nested numeric scalar.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if isnumeric(cursor) && isscalar(cursor)
    value = double(cursor);
end
end

function value = local_get_cellstr(S, path, defaultValue)
% Read optional nested cellstr.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
value = local_cellstr(cursor);
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function value = local_text_field(S, fieldName, defaultValue)
% Read optional scalar text field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName)) && ...
        (ischar(S.(fieldName)) || isstring(S.(fieldName)))
    value = char(S.(fieldName));
end
end

function value = local_numeric_field(S, fieldName, defaultValue)
% Read optional numeric scalar field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && isnumeric(S.(fieldName)) && isscalar(S.(fieldName))
    value = double(S.(fieldName));
end
end

function values = local_cellstr(values)
% Normalize text containers to a row cellstr.
if isempty(values)
    values = {};
elseif iscell(values)
    values = values(:)';
elseif isstring(values)
    values = cellstr(values(:))';
elseif ischar(values)
    values = cellstr(values);
    values = values(:)';
else
    values = {};
end
end
