function Logger = nf_save_partial_log(Logger, phase, reason)
% NF_SAVE_PARTIAL_LOG Save an incremental partial logger checkpoint.
%
% USAGE:  Logger = nf_save_partial_log(Logger, phase, reason)

%% ===== PARSE INPUTS =====
% Partial logs remain checkpoints, not finalized results.
if ~isstruct(Logger)
    error('Logger must be a struct.');
end
if nargin < 2 || isempty(phase)
    phase = Logger.Phase;
end
if nargin < 3 || isempty(reason)
    reason = 'unspecified';
end
phase = char(phase);
reason = char(reason);
savedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

%% ===== BUILD DELTAS =====
% Save only records appended since the previous partial checkpoint.
firstNewChunk = Logger.LastPartialSavedChunkIndex + 1;
lastNewChunk = Logger.NChunks;
firstNewMeasure = Logger.LastPartialSavedMeasureIndex + 1;
lastNewMeasure = Logger.NMeasures;

ChunkMetaDelta = local_slice_delta(Logger.ChunkMeta, firstNewChunk, lastNewChunk);
MeasuresDelta = local_slice_delta(Logger.Measures, firstNewMeasure, lastNewMeasure);

%% ===== PACKAGE PARTIAL LOG =====
% Do not include the full Logger; repeated partial saves must stay delta-based.
PartialLog = struct();
PartialLog.Type = 'partial_log';
PartialLog.Partial = true;
PartialLog.Finalized = false;
PartialLog.Phase = phase;
PartialLog.Reason = reason;
PartialLog.SavedAt = savedAt;
PartialLog.SessionDir = Logger.Session.SessionDir;
PartialLog.ConfigPath = Logger.ConfigPath;
PartialLog.SourcePath = Logger.SourcePath;
PartialLog.NChunksTotal = Logger.NChunks;
PartialLog.NMeasuresTotal = Logger.NMeasures;
PartialLog.FirstChunkIndex = firstNewChunk;
PartialLog.LastChunkIndex = lastNewChunk;
PartialLog.FirstMeasureIndex = firstNewMeasure;
PartialLog.LastMeasureIndex = lastNewMeasure;
PartialLog.ChunkMetaDelta = ChunkMetaDelta;
PartialLog.MeasuresDelta = MeasuresDelta;
PartialLog.Messages = Logger.Messages;

%% ===== SAVE PARTIAL CHECKPOINT =====
% Filename uniqueness is based on file existence, not timestamp alone.
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
basePath = fullfile(Logger.Session.LogsDir, ...
    ['partial_' local_sanitize_label(phase) '_' stamp '.mat']);
outPath = local_unique_file(basePath);
save(outPath, 'PartialLog');

Logger.Partial = true;
Logger.Finalized = false;
Logger.LastPartialSavePath = outPath;
Logger.PartialLogPaths{end + 1} = outPath;
Logger.LastPartialSavedChunkIndex = Logger.NChunks;
Logger.LastPartialSavedMeasureIndex = Logger.NMeasures;

end

function delta = local_slice_delta(S, firstIdx, lastIdx)
% Return empty or indexed delta without failing on no-new-record cases.
if isempty(S) || firstIdx > lastIdx || firstIdx < 1
    delta = S([]);
else
    delta = S(firstIdx:lastIdx);
end
end

function label = local_sanitize_label(labelIn)
% Keep filenames stable and readable.
label = char(labelIn);
label = regexprep(label, '[^a-zA-Z0-9_-]', '_');
label = regexprep(label, '_+', '_');
label = regexprep(label, '^_+|_+$', '');
if isempty(label)
    label = 'session';
end
end

function pathOut = local_unique_file(pathIn)
% Avoid overwriting partial checkpoints.
[folder, name, ext] = fileparts(pathIn);
pathOut = pathIn;
suffix = 0;
while exist(pathOut, 'file') ~= 0
    suffix = suffix + 1;
    pathOut = fullfile(folder, sprintf('%s_%03d%s', name, suffix, ext));
end
end
