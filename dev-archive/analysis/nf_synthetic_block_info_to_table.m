function T = nf_synthetic_block_info_to_table(BlockInfo, RTConfig, varargin)
% NF_SYNTHETIC_BLOCK_INFO_TO_TABLE Convert synthetic block metadata to table.
%
% USAGE:  T = nf_synthetic_block_info_to_table(BlockInfo, RTConfig)
%         T = nf_synthetic_block_info_to_table(..., 'ControlType', controlType)
%
% DESCRIPTION:
%     Builds a stable table describing known synthetic block timing, injected
%     frequency, amplitude, and whether the injection lies in the target band.

%% ===== PARSE INPUTS =====
% ControlType distinguishes theta-positive and wrong-band rows.
if nargin < 2 || isempty(RTConfig)
    RTConfig = struct();
end
controlType = local_parse_control_type(varargin{:});
columns = local_columns();

if isempty(BlockInfo) || ~isstruct(BlockInfo)
    T = local_empty_table(columns);
    return;
end

labels = local_labels(BlockInfo);
nBlocks = numel(labels);
if nBlocks == 0
    T = local_empty_table(columns);
    return;
end

meta = local_session_metadata(RTConfig);
targetBand = local_target_band(RTConfig);

%% ===== EXTRACT BLOCK FIELDS =====
% Missing block fields become NaN or false rather than causing failures.
BlockIndex = (1:nBlocks)';
BlockLabel = reshape(labels, [], 1);
StartSample = local_numeric_field(BlockInfo, 'StartSample', nBlocks);
EndSample = local_numeric_field(BlockInfo, 'EndSample', nBlocks);
StartTimeSec = local_time_field(BlockInfo, {'StartTimeSec','StartTime'}, nBlocks);
EndTimeSec = local_time_field(BlockInfo, {'EndTimeSec','EndTime'}, nBlocks);
InjectFreqHz = local_numeric_field(BlockInfo, 'InjectFreqHz', nBlocks);
Amplitude = local_numeric_field(BlockInfo, 'Amplitude', nBlocks);

DurationSec = EndTimeSec - StartTimeSec;
if any(~isfinite(DurationSec)) && isfield(RTConfig, 'Fs') && isfinite(RTConfig.Fs) && RTConfig.Fs > 0
    sampleDuration = (EndSample - StartSample + 1) ./ RTConfig.Fs;
    missing = ~isfinite(DurationSec) & isfinite(sampleDuration);
    DurationSec(missing) = sampleDuration(missing);
end

TargetBandLow = repmat(targetBand(1), nBlocks, 1);
TargetBandHigh = repmat(targetBand(2), nBlocks, 1);
hasInjection = isfinite(InjectFreqHz) & isfinite(Amplitude) & Amplitude ~= 0;
IsTargetBandInjection = hasInjection & isfinite(TargetBandLow) & isfinite(TargetBandHigh) & ...
    InjectFreqHz >= TargetBandLow & InjectFreqHz <= TargetBandHigh;
IsWrongBandInjection = hasInjection & ~IsTargetBandInjection;

%% ===== BUILD TABLE =====
% Text metadata are repeated per block.
RunID = repmat({meta.RunID}, nBlocks, 1);
DatasetName = repmat({meta.DatasetName}, nBlocks, 1);
ControlType = repmat({controlType}, nBlocks, 1);

T = table(RunID, DatasetName, ControlType, BlockIndex, BlockLabel, ...
    StartSample, EndSample, StartTimeSec, EndTimeSec, DurationSec, ...
    InjectFreqHz, Amplitude, TargetBandLow, TargetBandHigh, ...
    IsTargetBandInjection, IsWrongBandInjection, 'VariableNames', columns);

end

function columns = local_columns()
% Stable output schema for empty and nonempty tables.
columns = {'RunID','DatasetName','ControlType','BlockIndex','BlockLabel', ...
    'StartSample','EndSample','StartTimeSec','EndTimeSec','DurationSec', ...
    'InjectFreqHz','Amplitude','TargetBandLow','TargetBandHigh', ...
    'IsTargetBandInjection','IsWrongBandInjection'};
end

function T = local_empty_table(columns)
% Return an empty table with stable variable names and types.
nRows = 0;
emptyText = cell(nRows, 1);
emptyNum = NaN(nRows, 1);
emptyLogical = false(nRows, 1);
T = table(emptyText, emptyText, emptyText, emptyNum, emptyText, ...
    emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, ...
    emptyNum, emptyNum, emptyLogical, emptyLogical, 'VariableNames', columns);
end

function controlType = local_parse_control_type(varargin)
% Parse optional name/value inputs without requiring extra dependencies.
controlType = '';
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('Optional arguments must be name/value pairs.');
end
for iArg = 1:2:numel(varargin)
    name = char(varargin{iArg});
    value = varargin{iArg + 1};
    if strcmpi(name, 'ControlType')
        controlType = char(value);
    end
end
end

function meta = local_session_metadata(RTConfig)
% Read optional session metadata.
meta.RunID = local_get_nested_text(RTConfig, {'SessionMetadata','RunID'}, '');
meta.DatasetName = local_get_nested_text(RTConfig, {'SessionMetadata','DatasetName'}, '');
end

function labels = local_labels(BlockInfo)
% Normalize labels to a cellstr row.
labels = {};
if ~isfield(BlockInfo, 'Labels') || isempty(BlockInfo.Labels)
    return;
end
if iscell(BlockInfo.Labels)
    labels = BlockInfo.Labels(:)';
elseif isstring(BlockInfo.Labels)
    labels = cellstr(BlockInfo.Labels(:))';
elseif ischar(BlockInfo.Labels)
    labels = cellstr(BlockInfo.Labels)';
end
for iLabel = 1:numel(labels)
    labels{iLabel} = char(labels{iLabel});
end
end

function values = local_numeric_field(S, fieldName, nRows)
% Extract a numeric row field as an nRows-by-1 vector.
values = NaN(nRows, 1);
if isfield(S, fieldName) && isnumeric(S.(fieldName))
    raw = reshape(double(S.(fieldName)), [], 1);
    n = min(nRows, numel(raw));
    values(1:n) = raw(1:n);
end
end

function values = local_time_field(S, fieldNames, nRows)
% Extract time fields with backward-compatible field-name fallbacks.
values = NaN(nRows, 1);
for iField = 1:numel(fieldNames)
    if isfield(S, fieldNames{iField}) && isnumeric(S.(fieldNames{iField}))
        raw = reshape(double(S.(fieldNames{iField})), [], 1);
        n = min(nRows, numel(raw));
        values(1:n) = raw(1:n);
        return;
    end
end
end

function targetBand = local_target_band(RTConfig)
% Read configured target band.
targetBand = [NaN NaN];
if isfield(RTConfig, 'TargetBand') && isnumeric(RTConfig.TargetBand) && numel(RTConfig.TargetBand) >= 2
    targetBand = double(RTConfig.TargetBand(1:2));
end
targetBand = reshape(targetBand, 1, []);
end

function value = local_get_nested_text(S, path, defaultValue)
% Read a nested text field with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if isempty(current)
    return;
elseif ischar(current) || isstring(current)
    value = char(current);
elseif isnumeric(current) || islogical(current)
    value = num2str(current(1));
end
end
