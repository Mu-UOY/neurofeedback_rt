function T = nf_validation_to_table(Results, RTConfig)
% NF_VALIDATION_TO_TABLE Convert validation Results into an analysis table.
%
% USAGE:  T = nf_validation_to_table(Results)
%         T = nf_validation_to_table(Results, RTConfig)
%
% DESCRIPTION:
%     Builds a stable one-row table from the repository's validation Results
%     structs, including common nested fields when present. Missing fields are
%     filled with conservative defaults.

%% ===== PARSE INPUTS =====
% RTConfig is optional metadata.
if nargin < 2 || isempty(RTConfig)
    RTConfig = struct();
end

columns = local_columns();
if isempty(Results)
    T = local_empty_table(columns);
    return;
end
if ~isstruct(Results)
    error('Results must be a struct or empty.');
end

Results = Results(1);
meta = local_session_metadata(RTConfig);
targetBand = local_target_band(Results, RTConfig);

%% ===== EXTRACT VALIDATION FIELDS =====
% Prefer current nested fields, with flat fallbacks for small tests.
RunID = {meta.RunID};
DatasetName = {meta.DatasetName};
SourceMode = {local_get_nested_text(RTConfig, {'Source','Mode'}, '')};
TargetBandLow = targetBand(1);
TargetBandHigh = targetBand(2);
Correlation = local_first_numeric(Results, {{'Compare','Correlation'}, {'Correlation'}});
RMSE = local_first_numeric(Results, {{'Compare','RMSE'}, {'RMSE'}});
DelayCorrectedCorrelation = local_first_numeric(Results, ...
    {{'Delay','DelayCorrectedCorrelation'}, {'DelayCorrectedCorrelation'}});
EmpiricalDelaySamples = local_first_numeric(Results, ...
    {{'Delay','EmpiricalDelaySamples'}, {'EmpiricalDelaySamples'}});
if ~isfinite(EmpiricalDelaySamples)
    EmpiricalDelaySamples = local_get_nested_numeric(RTConfig, {'Filter','EmpiricalDelaySamples'}, NaN);
end
AnalyticGroupDelaySamples = local_first_numeric(Results, ...
    {{'Delay','AnalyticGroupDelaySamples'}, {'AnalyticGroupDelaySamples'}});
if ~isfinite(AnalyticGroupDelaySamples)
    AnalyticGroupDelaySamples = local_get_nested_numeric(RTConfig, {'Filter','AnalyticGroupDelaySamples'}, NaN);
end
DelayCorrectionUsed = local_first_numeric(Results, ...
    {{'Delay','DelayCorrectionUsed'}, {'DelayCorrectionUsed'}});
if ~isfinite(DelayCorrectionUsed)
    DelayCorrectionUsed = local_get_nested_numeric(RTConfig, {'Filter','DelayCorrectionUsed'}, NaN);
end
RuntimeStatus = {local_first_text(Results, {{'Runtime','Status'}, {'RuntimeStatus'}})};
DroppedChunkStatus = {local_first_text(Results, {{'DroppedChunks','Status'}, {'DroppedChunkStatus'}})};
BandDetectionStatus = {local_first_text(Results, ...
    {{'Step1','BandDetection','Status'}, {'Band','Status'}, {'BandDetectionStatus'}})};
PeakFrequency = local_first_numeric(Results, ...
    {{'Step1','BandDetection','PeakFrequency'}, {'Band','PeakFrequency'}, {'PeakFrequency'}});
PeakInsideTargetBand = local_first_logical(Results, ...
    {{'Step1','BandDetection','PeakInsideTargetBand'}, {'Band','PeakInsideTargetBand'}, {'PeakInsideTargetBand'}});
NChunks = local_first_numeric(Results, {{'NChunks'}});
NValidMeasures = local_first_numeric(Results, {{'NValidMeasures'}});
ConfigHash = {local_first_text(Results, {{'ConfigHash'}})};
Pass = local_results_pass(Results, RuntimeStatus{1}, DroppedChunkStatus{1}, BandDetectionStatus{1});

%% ===== CREATE TABLE =====
% Explicit columns avoid fragile conversion of nested structs.
T = table(RunID, DatasetName, SourceMode, TargetBandLow, TargetBandHigh, ...
    Correlation, RMSE, DelayCorrectedCorrelation, EmpiricalDelaySamples, ...
    AnalyticGroupDelaySamples, DelayCorrectionUsed, RuntimeStatus, ...
    DroppedChunkStatus, BandDetectionStatus, PeakFrequency, ...
    PeakInsideTargetBand, NChunks, NValidMeasures, ConfigHash, Pass, ...
    'VariableNames', columns);

end

function columns = local_columns()
% Stable output schema for empty and nonempty tables.
columns = {'RunID','DatasetName','SourceMode','TargetBandLow','TargetBandHigh', ...
    'Correlation','RMSE','DelayCorrectedCorrelation','EmpiricalDelaySamples', ...
    'AnalyticGroupDelaySamples','DelayCorrectionUsed','RuntimeStatus', ...
    'DroppedChunkStatus','BandDetectionStatus','PeakFrequency', ...
    'PeakInsideTargetBand','NChunks','NValidMeasures','ConfigHash','Pass'};
end

function T = local_empty_table(columns)
% Return an empty table with stable variable names and types.
nRows = 0;
emptyText = cell(nRows, 1);
emptyNum = NaN(nRows, 1);
emptyLogical = false(nRows, 1);

T = table(emptyText, emptyText, emptyText, emptyNum, emptyNum, emptyNum, ...
    emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyText, emptyText, ...
    emptyText, emptyNum, emptyLogical, emptyNum, emptyNum, emptyText, ...
    emptyLogical, 'VariableNames', columns);
end

function meta = local_session_metadata(RTConfig)
% Read optional SessionMetadata text labels.
meta.RunID = local_get_nested_text(RTConfig, {'SessionMetadata','RunID'}, '');
meta.DatasetName = local_get_nested_text(RTConfig, {'SessionMetadata','DatasetName'}, '');
end

function targetBand = local_target_band(Results, RTConfig)
% Prefer config target band; fall back to Results.Band metadata.
targetBand = [NaN NaN];
if isfield(RTConfig, 'TargetBand') && isnumeric(RTConfig.TargetBand) && numel(RTConfig.TargetBand) >= 2
    targetBand = double(RTConfig.TargetBand(1:2));
elseif isfield(Results, 'Band') && isfield(Results.Band, 'TargetBand') && ...
        isnumeric(Results.Band.TargetBand) && numel(Results.Band.TargetBand) >= 2
    targetBand = double(Results.Band.TargetBand(1:2));
elseif isfield(Results, 'Step1') && isfield(Results.Step1, 'BandDetection') && ...
        isfield(Results.Step1.BandDetection, 'TargetBand') && ...
        isnumeric(Results.Step1.BandDetection.TargetBand) && ...
        numel(Results.Step1.BandDetection.TargetBand) >= 2
    targetBand = double(Results.Step1.BandDetection.TargetBand(1:2));
end
targetBand = reshape(targetBand, 1, []);
end

function value = local_first_numeric(S, paths)
% Return the first finite numeric value from a list of nested paths.
value = NaN;
for iPath = 1:numel(paths)
    candidate = local_get_nested_numeric(S, paths{iPath}, NaN);
    if isfinite(candidate)
        value = candidate;
        return;
    end
end
end

function value = local_first_text(S, paths)
% Return the first nonempty text value from a list of nested paths.
value = '';
for iPath = 1:numel(paths)
    candidate = local_get_nested_text(S, paths{iPath}, '');
    if ~isempty(candidate)
        value = candidate;
        return;
    end
end
end

function value = local_first_logical(S, paths)
% Return the first logical value from a list of nested paths.
value = false;
for iPath = 1:numel(paths)
    [candidate, found] = local_get_nested_logical(S, paths{iPath}, false);
    if found
        value = candidate;
        return;
    end
end
end

function pass = local_results_pass(Results, runtimeStatus, droppedStatus, bandStatus)
% Infer pass conservatively only from explicit Pass or all known PASS statuses.
pass = false;
if isfield(Results, 'Pass') && ~isempty(Results.Pass)
    if islogical(Results.Pass) || isnumeric(Results.Pass)
        pass = logical(Results.Pass(1));
        return;
    end
end
if isfield(Results, 'Status') && ~isempty(Results.Status)
    pass = strcmp(char(Results.Status), 'PASS');
    return;
end

knownStatuses = {runtimeStatus, droppedStatus, bandStatus};
hasStatus = ~cellfun(@isempty, knownStatuses);
if any(hasStatus)
    activeStatuses = knownStatuses(hasStatus);
    pass = all(strcmp(activeStatuses, 'PASS'));
end
end

function value = local_get_nested_numeric(S, path, defaultValue)
% Read a nested numeric scalar with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if isnumeric(current) && ~isempty(current)
    value = double(current(1));
elseif islogical(current) && ~isempty(current)
    value = double(current(1));
end
end

function [value, found] = local_get_nested_logical(S, path, defaultValue)
% Read a nested logical scalar with a fallback.
value = defaultValue;
found = false;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if islogical(current) && ~isempty(current)
    value = logical(current(1));
    found = true;
elseif isnumeric(current) && ~isempty(current) && isfinite(current(1))
    value = current(1) ~= 0;
    found = true;
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
