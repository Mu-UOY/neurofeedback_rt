function T = nf_measures_to_table(Measures, RTConfig, Baseline)
% NF_MEASURES_TO_TABLE Convert Measure structs into an analysis table.
%
% USAGE:  T = nf_measures_to_table(Measures, RTConfig)
%         T = nf_measures_to_table(Measures, RTConfig, Baseline)
%
% DESCRIPTION:
%     Builds a stable table from possibly incomplete Measure structs. Missing
%     numeric fields become NaN, logical fields become false, and text fields
%     become empty strings.

%% ===== PARSE INPUTS =====
% RTConfig and Baseline are optional sources of metadata/provenance.
if nargin < 2 || isempty(RTConfig)
    RTConfig = struct();
end
if nargin < 3
    Baseline = [];
end

columns = local_columns();
if isempty(Measures)
    T = local_empty_table(columns);
    return;
end
if ~isstruct(Measures)
    error('Measures must be a struct array or empty.');
end

nRows = numel(Measures);
meta = local_session_metadata(RTConfig);
targetBand = local_target_band(RTConfig, Measures);
baselineHash = local_baseline_hash(Baseline);

%% ===== BUILD METADATA COLUMNS =====
% Metadata columns are repeated for every Measure row.
RunID = repmat({meta.RunID}, nRows, 1);
DatasetName = repmat({meta.DatasetName}, nRows, 1);
SubjectID = repmat({meta.SubjectID}, nRows, 1);
SessionID = repmat({meta.SessionID}, nRows, 1);
TrialID = repmat({meta.TrialID}, nRows, 1);
StrategyLabel = repmat({meta.StrategyLabel}, nRows, 1);
ConditionLabel = repmat({meta.ConditionLabel}, nRows, 1);
TargetBandLow = repmat(targetBand(1), nRows, 1);
TargetBandHigh = repmat(targetBand(2), nRows, 1);
BaselineConfigHash = repmat({baselineHash}, nRows, 1);

%% ===== BUILD MEASURE COLUMNS =====
% Extract each field as a scalar column, tolerating absent optional fields.
SourceMode = local_text_column(Measures, 'SourceMode', local_source_mode(RTConfig));
Time = local_numeric_column(Measures, 'Time');
NeuralWindowTime = local_numeric_column(Measures, 'NeuralWindowTime');
SampleIndex = local_numeric_column(Measures, 'SampleIndex');
AcquisitionSampleIndex = local_numeric_column(Measures, 'AcquisitionSampleIndex');
FilteredSampleIndex = local_numeric_column(Measures, 'FilteredSampleIndex');
WindowStartSample = local_numeric_column(Measures, 'WindowStartSample');
WindowEndSample = local_numeric_column(Measures, 'WindowEndSample');
WindowCenterSample = local_numeric_column(Measures, 'WindowCenterSample');
CorrectedWindowStartSample = local_numeric_column(Measures, 'CorrectedWindowStartSample');
CorrectedWindowEndSample = local_numeric_column(Measures, 'CorrectedWindowEndSample');
CorrectedWindowCenterSample = local_numeric_column(Measures, 'CorrectedWindowCenterSample');
Power = local_numeric_column(Measures, 'Power');
ZRaw = local_numeric_column(Measures, 'ZRaw');
ZClipped = local_numeric_column(Measures, 'ZClipped');
ZSmoothed = local_numeric_column(Measures, 'ZSmoothed');
FeedbackValue = local_numeric_column(Measures, 'FeedbackValue');
IsValid = local_logical_column(Measures, 'IsValid');
InvalidReason = local_text_column(Measures, 'InvalidReason', '');
DroppedChunkFlag = local_logical_column(Measures, 'DroppedChunkFlag');
GapInWindowFlag = local_logical_column(Measures, 'GapInWindowFlag');
ArtifactFlag = local_logical_column(Measures, 'ArtifactFlag');
TriggerSent = local_logical_column(Measures, 'TriggerSent');
AnalyticGroupDelaySamples = local_numeric_column(Measures, 'AnalyticGroupDelaySamples');
EmpiricalDelaySamples = local_numeric_column(Measures, 'EmpiricalDelaySamples');
DelayCorrectionUsed = local_numeric_column(Measures, 'DelayCorrectionUsed');
ConfigHash = local_text_column(Measures, 'ConfigHash', local_config_hash(RTConfig));

%% ===== CREATE TABLE =====
% Explicit columns avoid struct2table failures on inconsistent structs.
T = table(RunID, DatasetName, SubjectID, SessionID, TrialID, StrategyLabel, ...
    ConditionLabel, SourceMode, TargetBandLow, TargetBandHigh, Time, ...
    NeuralWindowTime, SampleIndex, AcquisitionSampleIndex, FilteredSampleIndex, ...
    WindowStartSample, WindowEndSample, WindowCenterSample, ...
    CorrectedWindowStartSample, CorrectedWindowEndSample, ...
    CorrectedWindowCenterSample, Power, ZRaw, ZClipped, ZSmoothed, ...
    FeedbackValue, IsValid, InvalidReason, DroppedChunkFlag, GapInWindowFlag, ...
    ArtifactFlag, TriggerSent, AnalyticGroupDelaySamples, EmpiricalDelaySamples, ...
    DelayCorrectionUsed, ConfigHash, BaselineConfigHash, ...
    'VariableNames', columns);

end

function columns = local_columns()
% Stable output schema for empty and nonempty tables.
columns = {'RunID','DatasetName','SubjectID','SessionID','TrialID', ...
    'StrategyLabel','ConditionLabel','SourceMode','TargetBandLow', ...
    'TargetBandHigh','Time','NeuralWindowTime','SampleIndex', ...
    'AcquisitionSampleIndex','FilteredSampleIndex','WindowStartSample', ...
    'WindowEndSample','WindowCenterSample','CorrectedWindowStartSample', ...
    'CorrectedWindowEndSample','CorrectedWindowCenterSample','Power', ...
    'ZRaw','ZClipped','ZSmoothed','FeedbackValue','IsValid', ...
    'InvalidReason','DroppedChunkFlag','GapInWindowFlag','ArtifactFlag', ...
    'TriggerSent','AnalyticGroupDelaySamples','EmpiricalDelaySamples', ...
    'DelayCorrectionUsed','ConfigHash','BaselineConfigHash'};
end

function T = local_empty_table(columns)
% Return an empty table with stable variable names and types.
nRows = 0;
emptyText = cell(nRows, 1);
emptyNum = NaN(nRows, 1);
emptyLogical = false(nRows, 1);

T = table(emptyText, emptyText, emptyText, emptyText, emptyText, emptyText, ...
    emptyText, emptyText, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, ...
    emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, ...
    emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, emptyNum, ...
    emptyLogical, emptyText, emptyLogical, emptyLogical, emptyLogical, ...
    emptyLogical, emptyNum, emptyNum, emptyNum, emptyText, emptyText, ...
    'VariableNames', columns);
end

function meta = local_session_metadata(RTConfig)
% Read optional SessionMetadata text labels.
fields = {'RunID','DatasetName','SubjectID','SessionID','TrialID', ...
    'StrategyLabel','ConditionLabel'};
meta = struct();
for iField = 1:numel(fields)
    meta.(fields{iField}) = local_get_nested_text(RTConfig, ...
        {'SessionMetadata', fields{iField}}, '');
end
end

function targetBand = local_target_band(RTConfig, Measures)
% Prefer config target band; fall back to the first Measure.Band.
targetBand = [NaN NaN];
if isfield(RTConfig, 'TargetBand') && isnumeric(RTConfig.TargetBand) && numel(RTConfig.TargetBand) >= 2
    targetBand = double(RTConfig.TargetBand(1:2));
elseif isstruct(Measures) && isfield(Measures, 'Band')
    band = Measures(1).Band;
    if isnumeric(band) && numel(band) >= 2
        targetBand = double(band(1:2));
    end
end
targetBand = reshape(targetBand, 1, []);
end

function value = local_source_mode(RTConfig)
% Read configured source mode.
value = local_get_nested_text(RTConfig, {'Source','Mode'}, '');
end

function value = local_config_hash(RTConfig)
% Read config hash when it is carried in the provided config-like struct.
value = local_get_nested_text(RTConfig, {'ConfigHash'}, '');
end

function value = local_baseline_hash(Baseline)
% Read baseline hash when a baseline was provided.
value = '';
if isstruct(Baseline) && isfield(Baseline, 'ConfigHash') && ~isempty(Baseline.ConfigHash)
    value = char(Baseline.ConfigHash);
end
end

function column = local_numeric_column(S, fieldName)
% Extract scalar numeric values, filling missing values with NaN.
nRows = numel(S);
column = NaN(nRows, 1);
for iRow = 1:nRows
    if isfield(S(iRow), fieldName)
        value = S(iRow).(fieldName);
        if isnumeric(value) && ~isempty(value)
            column(iRow) = double(value(1));
        elseif islogical(value) && ~isempty(value)
            column(iRow) = double(value(1));
        end
    end
end
end

function column = local_logical_column(S, fieldName)
% Extract scalar logical values, filling missing values with false.
nRows = numel(S);
column = false(nRows, 1);
for iRow = 1:nRows
    if isfield(S(iRow), fieldName)
        value = S(iRow).(fieldName);
        if islogical(value) && ~isempty(value)
            column(iRow) = logical(value(1));
        elseif isnumeric(value) && ~isempty(value) && isfinite(value(1))
            column(iRow) = value(1) ~= 0;
        end
    end
end
end

function column = local_text_column(S, fieldName, defaultValue)
% Extract scalar text values as a cellstr column.
nRows = numel(S);
column = repmat({char(defaultValue)}, nRows, 1);
for iRow = 1:nRows
    if isfield(S(iRow), fieldName) && ~isempty(S(iRow).(fieldName))
        value = S(iRow).(fieldName);
        if ischar(value) || isstring(value)
            column{iRow} = char(value);
        elseif isnumeric(value) || islogical(value)
            column{iRow} = num2str(value(1));
        end
    end
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
