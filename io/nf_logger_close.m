function Logger = nf_logger_close(Logger)
% NF_LOGGER_CLOSE Write final logger outputs and close the logger.
%
% USAGE:  Logger = nf_logger_close(Logger)

%% ===== HANDLE EMPTY/CLOSED LOGGER =====
% Close is idempotent for real logger structs and safe for empty input.
if isempty(Logger)
    return;
end
if ~isstruct(Logger)
    error('Logger must be a struct.');
end
if isfield(Logger, 'Closed') && Logger.Closed
    return;
end

%% ===== MARK FINALIZED =====
% Paths are assigned before FinalLog is packaged and saved.
closedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Logger.ClosedAt = closedAt;
Logger.Partial = false;
Logger.Finalized = true;
Logger.Closed = true;
if isfield(Logger, 'Session') && isstruct(Logger.Session)
    Logger.Session.IsPartial = false;
    Logger.Session.Finalized = true;
end

Logger.FinalLogPath = local_assign_path(Logger, 'FinalLogPath', 'final_log.mat');
Logger.MeasureTablePath = local_assign_path(Logger, 'MeasureTablePath', 'measures.csv');
Logger.ChunkMetaPath = local_assign_path(Logger, 'ChunkMetaPath', 'chunk_metadata.csv');
Logger.SessionSummaryPath = local_assign_path(Logger, 'SessionSummaryPath', 'session_summary.mat');

%% ===== SAVE FINAL MAT LOG =====
% The complete Logger is written once on close.
FinalLog = struct();
FinalLog.Type = 'logger_final_log';
FinalLog.Partial = false;
FinalLog.Finalized = true;
FinalLog.ClosedAt = closedAt;
FinalLog.Logger = Logger;
save(Logger.FinalLogPath, 'FinalLog');

%% ===== SAVE MEASURE TABLE =====
% CSV failure should not lose the final MAT audit log.
if Logger.NMeasures > 0
    try
        TMeasures = nf_measures_to_table(Logger.Measures, Logger.RTConfig);
        writetable(TMeasures, Logger.MeasureTablePath);
    catch ME
        Logger.Messages{end + 1} = ...
            sprintf('Measure CSV export failed: %s', ME.message);
    end
end

%% ===== SAVE CHUNK METADATA TABLE =====
% Keep nested correction details in MAT; CSV gets a compact summary.
if Logger.NChunks > 0
    try
        TChunks = local_chunk_table(Logger.ChunkMeta);
        writetable(TChunks, Logger.ChunkMetaPath);
    catch ME
        Logger.Messages{end + 1} = ...
            sprintf('Chunk metadata CSV export failed: %s', ME.message);
    end
end

%% ===== SAVE SESSION SUMMARY =====
% Summary is compact and easy to load without the full Logger payload.
SessionSummary = struct();
SessionSummary.Phase = Logger.Phase;
SessionSummary.NChunks = Logger.NChunks;
SessionSummary.NMeasures = Logger.NMeasures;
SessionSummary.CreatedAt = Logger.CreatedAt;
SessionSummary.ClosedAt = Logger.ClosedAt;
SessionSummary.Finalized = Logger.Finalized;
SessionSummary.Partial = Logger.Partial;
SessionSummary.SessionDir = Logger.Session.SessionDir;
SessionSummary.Messages = Logger.Messages;
SessionSummary.PartialLogPaths = Logger.PartialLogPaths;
save(Logger.SessionSummaryPath, 'SessionSummary');

end

function pathOut = local_assign_path(Logger, fieldName, fileName)
% Assign final paths once; keep existing paths on double/same-instance closes.
if isfield(Logger, fieldName) && ~isempty(Logger.(fieldName))
    pathOut = Logger.(fieldName);
    return;
end
pathOut = fullfile(Logger.Session.LogsDir, fileName);
if exist(pathOut, 'file') == 0
    return;
end

[folder, name, ext] = fileparts(pathOut);
suffix = 0;
while exist(pathOut, 'file') ~= 0
    suffix = suffix + 1;
    pathOut = fullfile(folder, sprintf('%s_%03d%s', name, suffix, ext));
end
end

function T = local_chunk_table(ChunkMeta)
% Convert normalized chunk metadata into a stable, shallow CSV table.
n = numel(ChunkMeta);
RunID = local_text_column(ChunkMeta, 'RunID');
Phase = local_text_column(ChunkMeta, 'Phase');
ChunkIndex = local_numeric_column(ChunkMeta, 'ChunkIndex');
StartSample = local_numeric_column(ChunkMeta, 'StartSample');
StopSample = local_numeric_column(ChunkMeta, 'StopSample');
SampleIndex = local_numeric_column(ChunkMeta, 'SampleIndex');
NSamples = local_numeric_column(ChunkMeta, 'NSamples');
NChannels = local_numeric_column(ChunkMeta, 'NChannels');
ReadStartTime = local_numeric_column(ChunkMeta, 'ReadStartTime');
ReadEndTime = local_numeric_column(ChunkMeta, 'ReadEndTime');
ProcessingStartTime = local_numeric_column(ChunkMeta, 'ProcessingStartTime');
ProcessingEndTime = local_numeric_column(ChunkMeta, 'ProcessingEndTime');
DroppedChunkFlag = local_logical_column(ChunkMeta, 'DroppedChunkFlag');
GapBeforeChunkFlag = local_logical_column(ChunkMeta, 'GapBeforeChunkFlag');
TimeoutFlag = local_logical_column(ChunkMeta, 'TimeoutFlag');
RuntimeSecs = local_numeric_column(ChunkMeta, 'RuntimeSecs');
SourceMode = local_text_column(ChunkMeta, 'SourceMode');
ReadHeaderNSamples = local_numeric_column(ChunkMeta, 'ReadHeaderNSamples');
FieldTripReadStart = local_numeric_column(ChunkMeta, 'FieldTripReadStart');
FieldTripReadStop = local_numeric_column(ChunkMeta, 'FieldTripReadStop');
IndexingMode = local_text_column(ChunkMeta, 'IndexingMode');
CorrectionSummary = repmat({''}, n, 1);
for iRow = 1:n
    if isfield(ChunkMeta(iRow), 'CorrectionInfo') && ...
            ~isempty(fieldnames(ChunkMeta(iRow).CorrectionInfo))
        CorrectionSummary{iRow} = strjoin(fieldnames(ChunkMeta(iRow).CorrectionInfo), ',');
    end
end

T = table(RunID, Phase, ChunkIndex, StartSample, StopSample, SampleIndex, ...
    NSamples, NChannels, ReadStartTime, ReadEndTime, ProcessingStartTime, ...
    ProcessingEndTime, DroppedChunkFlag, GapBeforeChunkFlag, TimeoutFlag, ...
    RuntimeSecs, SourceMode, ReadHeaderNSamples, FieldTripReadStart, ...
    FieldTripReadStop, IndexingMode, CorrectionSummary);
end

function column = local_text_column(S, fieldName)
column = repmat({''}, numel(S), 1);
for iRow = 1:numel(S)
    if isfield(S(iRow), fieldName) && ~isempty(S(iRow).(fieldName))
        column{iRow} = char(S(iRow).(fieldName));
    end
end
end

function column = local_numeric_column(S, fieldName)
column = NaN(numel(S), 1);
for iRow = 1:numel(S)
    if isfield(S(iRow), fieldName) && isnumeric(S(iRow).(fieldName)) && ...
            ~isempty(S(iRow).(fieldName))
        column(iRow) = double(S(iRow).(fieldName)(1));
    end
end
end

function column = local_logical_column(S, fieldName)
column = false(numel(S), 1);
for iRow = 1:numel(S)
    if isfield(S(iRow), fieldName) && ~isempty(S(iRow).(fieldName))
        value = S(iRow).(fieldName);
        if islogical(value) && isscalar(value)
            column(iRow) = value;
        elseif isnumeric(value) && isscalar(value) && isfinite(value)
            column(iRow) = value ~= 0;
        end
    end
end
end
