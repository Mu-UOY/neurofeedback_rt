function Logger = nf_logger_append_chunk_meta(Logger, chunkMeta)
% NF_LOGGER_APPEND_CHUNK_META Append normalized chunk metadata.
%
% USAGE:  Logger = nf_logger_append_chunk_meta(Logger, chunkMeta)

%% ===== CHECK INPUT =====
% Empty chunk metadata is only recorded as a message.
if isempty(chunkMeta)
    Logger.Messages{end + 1} = 'Empty chunk metadata input was not appended.';
    return;
end
if ~isstruct(Logger)
    error('Logger must be a struct.');
end
if ~isstruct(chunkMeta)
    error('chunkMeta must be a struct or empty.');
end

%% ===== NORMALIZE AND APPEND =====
% Raw data matrices are intentionally stripped from the log record.
record = local_empty_chunk_record();
record.RunID = local_nested_text(Logger, {'RTConfig','SessionMetadata','RunID'}, '');
record.Phase = local_text(chunkMeta, 'Phase', Logger.Phase);
record.ChunkIndex = local_numeric(chunkMeta, 'ChunkIndex', Logger.NChunks + 1);
record.NSamples = local_nsamples(chunkMeta);
record.NChannels = local_nchannels(chunkMeta);
record.SampleIndex = local_numeric(chunkMeta, 'SampleIndex', NaN);
record.StartSample = local_start_sample(chunkMeta, record.SampleIndex);
record.StopSample = local_stop_sample(chunkMeta, record.StartSample, record.NSamples);
record.ReadStartTime = local_numeric(chunkMeta, 'ReadStartTime', NaN);
record.ReadEndTime = local_numeric(chunkMeta, 'ReadEndTime', NaN);
record.ProcessingStartTime = local_numeric(chunkMeta, 'ProcessingStartTime', NaN);
record.ProcessingEndTime = local_numeric(chunkMeta, 'ProcessingEndTime', NaN);
record.DroppedChunkFlag = local_logical(chunkMeta, 'DroppedChunkFlag', false);
record.GapBeforeChunkFlag = local_logical(chunkMeta, 'GapBeforeChunkFlag', false);
record.TimeoutFlag = local_timeout_flag(chunkMeta);
record.CorrectionInfo = local_struct(chunkMeta, 'CorrectionInfo');
record.RuntimeSecs = local_runtime_secs(record);
record.SourceMode = local_text(chunkMeta, 'SourceMode', ...
    local_nested_text(Logger, {'RTConfig','Source','Mode'}, ''));
record.ReadHeaderNSamples = local_numeric(chunkMeta, 'ReadHeaderNSamples', NaN);
readRange = local_read_range(chunkMeta);
record.FieldTripReadStart = readRange(1);
record.FieldTripReadStop = readRange(2);
record.IndexingMode = local_text(chunkMeta, 'IndexingMode', '');

Logger.NChunks = Logger.NChunks + 1;
if isempty(Logger.ChunkMeta)
    Logger.ChunkMeta = record;
else
    Logger.ChunkMeta(end + 1) = record;
end

if isfield(Logger.RTConfig, 'Logging') && ...
        isfield(Logger.RTConfig.Logging, 'SaveRawChunksLocal') && ...
        Logger.RTConfig.Logging.SaveRawChunksLocal
    Logger.Messages{end + 1} = ...
        'Raw chunk saving requested but deferred in Step 3A-0d.';
end

end

function record = local_empty_chunk_record()
record = struct();
record.RunID = '';
record.Phase = '';
record.ChunkIndex = NaN;
record.StartSample = NaN;
record.StopSample = NaN;
record.SampleIndex = NaN;
record.NSamples = NaN;
record.NChannels = NaN;
record.ReadStartTime = NaN;
record.ReadEndTime = NaN;
record.ProcessingStartTime = NaN;
record.ProcessingEndTime = NaN;
record.DroppedChunkFlag = false;
record.GapBeforeChunkFlag = false;
record.TimeoutFlag = false;
record.CorrectionInfo = struct();
record.RuntimeSecs = NaN;
record.SourceMode = '';
record.ReadHeaderNSamples = NaN;
record.FieldTripReadStart = NaN;
record.FieldTripReadStop = NaN;
record.IndexingMode = '';
end

function value = local_text(S, fieldName, defaultValue)
value = defaultValue;
if isfield(S, fieldName) && ~isempty(S.(fieldName)) && ...
        (ischar(S.(fieldName)) || isstring(S.(fieldName)))
    value = char(S.(fieldName));
end
end

function value = local_numeric(S, fieldName, defaultValue)
value = defaultValue;
if isfield(S, fieldName) && isnumeric(S.(fieldName)) && ~isempty(S.(fieldName))
    value = double(S.(fieldName)(1));
end
end

function value = local_logical(S, fieldName, defaultValue)
value = defaultValue;
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    x = S.(fieldName);
    if islogical(x) && isscalar(x)
        value = x;
    elseif isnumeric(x) && isscalar(x) && isfinite(x)
        value = x ~= 0;
    end
end
end

function value = local_struct(S, fieldName)
value = struct();
if isfield(S, fieldName) && isstruct(S.(fieldName))
    value = S.(fieldName);
end
end

function n = local_nsamples(S)
n = local_numeric(S, 'NSamples', NaN);
if ~isfinite(n) && isfield(S, 'Data') && isnumeric(S.Data)
    n = size(S.Data, 2);
elseif ~isfinite(n) && isfield(S, 'SampleIndices') && isnumeric(S.SampleIndices)
    n = numel(S.SampleIndices);
end
end

function n = local_nchannels(S)
n = local_numeric(S, 'NChannels', NaN);
if ~isfinite(n) && isfield(S, 'ChannelNames') && iscell(S.ChannelNames)
    n = numel(S.ChannelNames);
elseif ~isfinite(n) && isfield(S, 'Data') && isnumeric(S.Data)
    n = size(S.Data, 1);
end
end

function startSample = local_start_sample(S, sampleIndex)
startSample = NaN;
if isfield(S, 'SampleIndices') && isnumeric(S.SampleIndices) && ~isempty(S.SampleIndices)
    startSample = double(S.SampleIndices(1));
elseif isfinite(sampleIndex)
    startSample = sampleIndex;
end
end

function stopSample = local_stop_sample(S, startSample, nSamples)
stopSample = NaN;
if isfield(S, 'SampleIndices') && isnumeric(S.SampleIndices) && ~isempty(S.SampleIndices)
    stopSample = double(S.SampleIndices(end));
elseif isfinite(startSample) && isfinite(nSamples)
    stopSample = startSample + nSamples - 1;
end
end

function tf = local_timeout_flag(S)
tf = local_logical(S, 'TimeoutFlag', false);
textFields = {'Status','Error','Message'};
for iField = 1:numel(textFields)
    fieldName = textFields{iField};
    if isfield(S, fieldName) && ~isempty(S.(fieldName)) && ...
            contains(lower(char(S.(fieldName))), 'timeout')
        tf = true;
    end
end
end

function value = local_read_range(S)
value = [NaN NaN];
if isfield(S, 'FieldTripReadRange') && isnumeric(S.FieldTripReadRange) && numel(S.FieldTripReadRange) >= 2
    value = double(S.FieldTripReadRange(1:2));
elseif isfield(S, 'ReadRangeSamples') && isnumeric(S.ReadRangeSamples) && numel(S.ReadRangeSamples) >= 2
    value = double(S.ReadRangeSamples(1:2));
elseif isfield(S, 'RequestedGetDatRange') && isnumeric(S.RequestedGetDatRange) && numel(S.RequestedGetDatRange) >= 2
    value = double(S.RequestedGetDatRange(1:2));
end
value = value(:)';
end

function runtimeSecs = local_runtime_secs(record)
runtimeSecs = NaN;
if isfinite(record.ProcessingStartTime) && isfinite(record.ProcessingEndTime)
    runtimeSecs = record.ProcessingEndTime - record.ProcessingStartTime;
elseif isfinite(record.ReadStartTime) && isfinite(record.ReadEndTime)
    runtimeSecs = record.ReadEndTime - record.ReadStartTime;
end
end

function value = local_nested_text(S, path, defaultValue)
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if ischar(current) || isstring(current)
    value = char(current);
end
end
