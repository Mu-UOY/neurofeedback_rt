function T = nf_baseline_to_table(Baseline, RTConfig)
% NF_BASELINE_TO_TABLE Convert a finalized baseline into an analysis table.
%
% USAGE:  T = nf_baseline_to_table(Baseline)
%         T = nf_baseline_to_table(Baseline, RTConfig)
%
% DESCRIPTION:
%     Builds a one-row table from a baseline struct. Missing numeric fields
%     become NaN, logical fields become false, and text fields become empty
%     strings. Empty baseline input returns an empty table with stable columns.

%% ===== PARSE INPUTS =====
% RTConfig is optional metadata.
if nargin < 2 || isempty(RTConfig)
    RTConfig = struct();
end

columns = local_columns();
if isempty(Baseline)
    T = local_empty_table(columns);
    return;
end
if ~isstruct(Baseline)
    error('Baseline must be a struct or empty.');
end

Baseline = Baseline(1);
meta = local_session_metadata(RTConfig);
targetBand = local_target_band(Baseline, RTConfig);

%% ===== READ CANONICAL AND ALIAS STATS =====
% Mean/Std are canonical; PowerMean/PowerStd are aliases when available.
meanValue = local_numeric_field(Baseline, 'Mean');
stdValue = local_numeric_field(Baseline, 'Std');
powerMean = local_numeric_field(Baseline, 'PowerMean');
powerStd = local_numeric_field(Baseline, 'PowerStd');

if ~isfinite(meanValue) && isfinite(powerMean)
    meanValue = powerMean;
end
if ~isfinite(stdValue) && isfinite(powerStd)
    stdValue = powerStd;
end
if ~isfinite(powerMean) && isfinite(meanValue)
    powerMean = meanValue;
end
if ~isfinite(powerStd) && isfinite(stdValue)
    powerStd = stdValue;
end

%% ===== BUILD TABLE COLUMNS =====
% Use scalar columns so the output remains stable for downstream joins.
RunID = {meta.RunID};
DatasetName = {meta.DatasetName};
SourceMode = {local_source_mode(Baseline, RTConfig)};
TargetBandLow = targetBand(1);
TargetBandHigh = targetBand(2);
Mean = meanValue;
Std = stdValue;
PowerMean = powerMean;
PowerStd = powerStd;
ValidWindowCount = local_numeric_field(Baseline, 'ValidWindowCount');
UsableWindowCount = local_numeric_field(Baseline, 'UsableWindowCount');
InvalidWindowCount = local_numeric_field(Baseline, 'InvalidWindowCount');
GapWindowCount = local_numeric_field(Baseline, 'GapWindowCount');
ArtifactWindowCount = local_numeric_field(Baseline, 'ArtifactWindowCount');
NTrimmedRejected = local_numeric_field(Baseline, 'NTrimmedRejected');
OutlierMethod = {local_text_field(Baseline, 'OutlierMethod')};
[OutlierThresholdLow, OutlierThresholdHigh] = local_outlier_thresholds(Baseline);
QualityPass = local_get_nested_logical(Baseline, {'Quality','Pass'}, false);
QualityStatus = {local_get_nested_text(Baseline, {'Quality','Status'}, '')};
QualityMessage = {local_get_nested_text(Baseline, {'Quality','Message'}, '')};
ConfigHash = {local_text_field(Baseline, 'ConfigHash')};
ConfigHashCreatedAt = {local_text_field(Baseline, 'ConfigHashCreatedAt')};

T = table(RunID, DatasetName, SourceMode, TargetBandLow, TargetBandHigh, ...
    Mean, Std, PowerMean, PowerStd, ValidWindowCount, UsableWindowCount, ...
    InvalidWindowCount, GapWindowCount, ArtifactWindowCount, ...
    NTrimmedRejected, OutlierMethod, OutlierThresholdLow, ...
    OutlierThresholdHigh, QualityPass, QualityStatus, QualityMessage, ...
    ConfigHash, ConfigHashCreatedAt, 'VariableNames', columns);

end

function columns = local_columns()
% Stable output schema for empty and nonempty tables.
columns = {'RunID','DatasetName','SourceMode','TargetBandLow','TargetBandHigh', ...
    'Mean','Std','PowerMean','PowerStd','ValidWindowCount','UsableWindowCount', ...
    'InvalidWindowCount','GapWindowCount','ArtifactWindowCount', ...
    'NTrimmedRejected','OutlierMethod','OutlierThresholdLow', ...
    'OutlierThresholdHigh','QualityPass','QualityStatus','QualityMessage', ...
    'ConfigHash','ConfigHashCreatedAt'};
end

function T = local_empty_table(columns)
% Return an empty table with stable variable names and types.
nRows = 0;
emptyText = cell(nRows, 1);
emptyNum = NaN(nRows, 1);
emptyLogical = false(nRows, 1);

T = table(emptyText, emptyText, emptyText, emptyNum, emptyNum, emptyNum, ...
    emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, ...
    emptyNum, emptyNum, emptyText, emptyNum, emptyNum, emptyLogical, ...
    emptyText, emptyText, emptyText, emptyText, 'VariableNames', columns);
end

function meta = local_session_metadata(RTConfig)
% Read optional SessionMetadata text labels.
meta.RunID = local_get_nested_text(RTConfig, {'SessionMetadata','RunID'}, '');
meta.DatasetName = local_get_nested_text(RTConfig, {'SessionMetadata','DatasetName'}, '');
end

function targetBand = local_target_band(Baseline, RTConfig)
% Prefer config target band; fall back to baseline metadata.
targetBand = [NaN NaN];
if isfield(RTConfig, 'TargetBand') && isnumeric(RTConfig.TargetBand) && numel(RTConfig.TargetBand) >= 2
    targetBand = double(RTConfig.TargetBand(1:2));
elseif isfield(Baseline, 'Metadata') && isfield(Baseline.Metadata, 'TargetBand') && ...
        isnumeric(Baseline.Metadata.TargetBand) && numel(Baseline.Metadata.TargetBand) >= 2
    targetBand = double(Baseline.Metadata.TargetBand(1:2));
end
targetBand = reshape(targetBand, 1, []);
end

function value = local_source_mode(Baseline, RTConfig)
% Prefer configured source mode; fall back to baseline metadata.
value = local_get_nested_text(RTConfig, {'Source','Mode'}, '');
if isempty(value)
    value = local_get_nested_text(Baseline, {'Metadata','SourceMode'}, '');
end
end

function value = local_numeric_field(S, fieldName)
% Read a scalar numeric field.
value = NaN;
if isfield(S, fieldName)
    fieldValue = S.(fieldName);
    if isnumeric(fieldValue) && ~isempty(fieldValue)
        value = double(fieldValue(1));
    elseif islogical(fieldValue) && ~isempty(fieldValue)
        value = double(fieldValue(1));
    end
end
end

function value = local_text_field(S, fieldName)
% Read a scalar text field.
value = '';
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    fieldValue = S.(fieldName);
    if ischar(fieldValue) || isstring(fieldValue)
        value = char(fieldValue);
    elseif isnumeric(fieldValue) || islogical(fieldValue)
        value = num2str(fieldValue(1));
    end
end
end

function [low, high] = local_outlier_thresholds(Baseline)
% Read common outlier-threshold audit fields.
low = NaN;
high = NaN;
if ~isfield(Baseline, 'OutlierThresholds') || ~isstruct(Baseline.OutlierThresholds)
    return;
end
thresholds = Baseline.OutlierThresholds;
if isfield(thresholds, 'LowValue') && isnumeric(thresholds.LowValue) && ~isempty(thresholds.LowValue)
    low = double(thresholds.LowValue(1));
end
if isfield(thresholds, 'HighValue') && isnumeric(thresholds.HighValue) && ~isempty(thresholds.HighValue)
    high = double(thresholds.HighValue(1));
end
end

function value = local_get_nested_logical(S, path, defaultValue)
% Read a nested logical field with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if islogical(current) && ~isempty(current)
    value = logical(current(1));
elseif isnumeric(current) && ~isempty(current) && isfinite(current(1))
    value = current(1) ~= 0;
end
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
