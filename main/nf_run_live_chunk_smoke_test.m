function Result = nf_run_live_chunk_smoke_test(RTConfig)
% NF_RUN_LIVE_CHUNK_SMOKE_TEST Run repeated live raw-chunk acquisition checks.
%
% USAGE:  Result = nf_run_live_chunk_smoke_test(RTConfig)
%
% DESCRIPTION:
%     Acquisition-only Step 3B smoke test. It initializes the live FieldTrip
%     source through nf_source_init, reads repeated chunks through
%     nf_get_meg_chunk, validates chunk metadata, and saves a report.

%% ===== PREPARE CONFIG =====
% Do not override operator/test connection settings except the session mode.
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_live_config();
end
Modes = nf_modes();
RTConfig.Session.Mode = Modes.Session.LiveChunkSmokeTest;

requestedProjectRoot = '';
if isfield(RTConfig, 'Paths') && isfield(RTConfig.Paths, 'ProjectRoot')
    requestedProjectRoot = RTConfig.Paths.ProjectRoot;
end

RTConfig = nf_finalize_config(RTConfig);
if ~isempty(requestedProjectRoot)
    RTConfig.Paths.ProjectRoot = requestedProjectRoot;
end

NChunks = RTConfig.LiveChunkSmokeTest.NChunks;
Result = local_empty_result(RTConfig, NChunks);

%% ===== INITIALIZE LIVE SOURCE AND SAFETY =====
% Source initialization is Step 3A's responsibility and may fail clearly.
Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
Result = local_populate_source_fields(Result, Source, RTConfig);
Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveChunkSmokeTest);

%% ===== READ AND VALIDATE CHUNKS =====
% No RT processing, spatial projection, baseline, trial, or feedback occurs here.
metadataRows = repmat(local_empty_metadata_row(), 0, 1);
firstChunkPreview = [];
previousLastSample = NaN;
expectedNChannels = Result.NChannels;

for iChunk = 1:NChunks
    [stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
    if stopRequested
        Result.StopReason = 'manual';
        Result.Status = 'STOPPED';
        Result.Messages{end+1} = 'Manual stop requested before chunk read.';
        break;
    end
    if nf_safety_hard_failsafe_exceeded(Safety)
        Result.StopReason = 'hard_failsafe';
        Result.Messages{end+1} = 'Hard failsafe exceeded before chunk read.';
        break;
    end

    readStartTime = local_now_text();
    tRead = tic;
    try
        [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
        readError = [];
    catch ME
        chunk = [];
        readError = ME;
    end
    readRuntimeSecs = toc(tRead);
    readEndTime = local_now_text();

    if ~isempty(readError)
        Result.NInvalidChunks = Result.NInvalidChunks + 1;
        row = local_source_error_row(Result.RunID, iChunk, RTConfig, expectedNChannels, ...
            Source, readStartTime, readEndTime, readRuntimeSecs, readError);
        metadataRows(end+1) = row; %#ok<AGROW>
        Result.Messages{end+1} = sprintf('Chunk %d source read error: %s', ...
            iChunk, readError.message);
        Result.StopReason = 'source_read_error';
        break;
    elseif isempty(chunk)
        Result.NTimeouts = Result.NTimeouts + 1;
        metadataRows(end+1) = local_timeout_row(Result.RunID, iChunk, RTConfig, ... %#ok<AGROW>
            expectedNChannels, Source, readStartTime, readEndTime, readRuntimeSecs);
        if Result.NTimeouts > RTConfig.LiveChunkSmokeTest.MaxTimeouts
            Result.StopReason = 'timeout_limit_exceeded';
            Result.Messages{end+1} = sprintf('Timeout limit exceeded after chunk %d.', iChunk);
            break;
        end
    else
        Result.NReadChunks = Result.NReadChunks + 1;
        [row, invalidMessages, previousLastSample, expectedNChannels] = ...
            local_validate_chunk(chunk, Source, RTConfig, Result.RunID, iChunk, ...
            previousLastSample, expectedNChannels, readStartTime, readEndTime, readRuntimeSecs);
        metadataRows(end+1) = row; %#ok<AGROW>

        if row.InvalidChunkFlag
            Result.NInvalidChunks = Result.NInvalidChunks + 1;
            Result.Messages = [Result.Messages, invalidMessages];
        end

        if isempty(firstChunkPreview) && RTConfig.LiveChunkSmokeTest.SaveFirstChunkPreview
            firstChunkPreview = local_first_chunk_preview(chunk);
        end
    end

    [stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
    if stopRequested
        Result.StopReason = 'manual';
        if Result.NReadChunks < Result.NRequestedChunks
            Result.Status = 'STOPPED';
            Result.Messages{end+1} = 'Manual stop requested after chunk read.';
        end
        break;
    end
    if nf_safety_hard_failsafe_exceeded(Safety)
        Result.StopReason = 'hard_failsafe';
        Result.Messages{end+1} = 'Hard failsafe exceeded after chunk read.';
        break;
    end
end

%% ===== FINALIZE RESULT =====
% Convert metadata rows to a stable table before saving.
if isempty(metadataRows)
    Result.MetadataTable = struct2table(repmat(local_empty_metadata_row(), 0, 1));
else
    Result.MetadataTable = struct2table(metadataRows);
end

if ~isempty(Result.MetadataTable)
    nonTimeoutRows = ~Result.MetadataTable.TimeoutFlag;
    if any(nonTimeoutRows)
        Result.ChunkSizePass = all(Result.MetadataTable.NSamples(nonTimeoutRows) == RTConfig.ChunkSamples) && ...
            ~any(contains(Result.MetadataTable.InvalidReason(nonTimeoutRows), 'chunk_size'));
        Result.InternalChunkContinuityPass = all(Result.MetadataTable.InternalContinuityPass(nonTimeoutRows));
        Result.CrossChunkContinuityPass = all(Result.MetadataTable.CrossChunkContinuityPass(nonTimeoutRows));
        Result.ChannelCountStablePass = ~any(contains(Result.MetadataTable.InvalidReason(nonTimeoutRows), 'channel_count'));
    end
end
Result.SampleContinuityPass = Result.InternalChunkContinuityPass && Result.CrossChunkContinuityPass;
Result.TimeoutPass = Result.NTimeouts <= RTConfig.LiveChunkSmokeTest.MaxTimeouts;

if ~isempty(Result.MetadataTable) && any(~isnan(Result.MetadataTable.FirstSample))
    Result.FirstSample = Result.MetadataTable.FirstSample(find(~isnan(Result.MetadataTable.FirstSample), 1, 'first'));
    Result.LastSample = Result.MetadataTable.LastSample(find(~isnan(Result.MetadataTable.LastSample), 1, 'last'));
end

Result.CorrectionSummary = local_correction_summary(Result.MetadataTable, Source);
Result = local_finalize_pass_fail(Result, RTConfig);

%% ===== SAVE REPORT =====
% Saving failures throw from the helper.
Result = nf_save_live_chunk_smoke_test(Result, RTConfig, Source, firstChunkPreview);
nf_safety_shutdown(Safety);

end

function Result = local_empty_result(RTConfig, NChunks)
% Create the stable Result schema.
Result = struct();
Result.Type = 'live_chunk_smoke_test';
Result.Pass = false;
Result.Status = 'FAIL';
Result.Message = '';
Result.StopReason = '';
Result.RunID = local_run_id();
Result.SessionDir = '';
Result.ReportMatPath = '';
Result.ReportTextPath = '';
Result.MetadataCsvPath = '';
Result.FirstChunkPreviewPath = '';
Result.NRequestedChunks = NChunks;
Result.NReadChunks = 0;
Result.NTimeouts = 0;
Result.NInvalidChunks = 0;
Result.Fs = NaN;
Result.ExpectedFs = 2400;
Result.ChunkSamples = RTConfig.ChunkSamples;
Result.ExpectedChunkSamples = 480;
Result.NChannels = NaN;
Result.ChannelNames = {};
Result.FirstSample = NaN;
Result.LastSample = NaN;
Result.SampleContinuityPass = false;
Result.InternalChunkContinuityPass = false;
Result.CrossChunkContinuityPass = false;
Result.ChannelCountStablePass = false;
Result.ChunkSizePass = false;
Result.TimeoutPass = false;
Result.MetadataTable = table();
Result.CorrectionSummary = struct();
Result.Messages = {};
end

function Result = local_populate_source_fields(Result, Source, RTConfig)
% Copy source audit fields into Result.
if isfield(Source, 'Fs')
    Result.Fs = Source.Fs;
end
if isfield(RTConfig, 'LiveDryRun') && isfield(RTConfig.LiveDryRun, 'ExpectedFs')
    Result.ExpectedFs = RTConfig.LiveDryRun.ExpectedFs;
end
if isfield(Source, 'ChannelNamesAfterCorrection') && ~isempty(Source.ChannelNamesAfterCorrection)
    Result.ChannelNames = Source.ChannelNamesAfterCorrection;
elseif isfield(Source, 'ChannelNames')
    Result.ChannelNames = Source.ChannelNames;
end
Result.NChannels = numel(Result.ChannelNames);
end

function row = local_empty_metadata_row()
% Stable metadata schema: one row per attempted chunk.
row = struct();
row.RunID = '';
row.ChunkIndex = NaN;
row.TimeoutFlag = false;
row.InvalidChunkFlag = false;
row.InvalidReason = '';
row.StartSample = NaN;
row.StopSample = NaN;
row.NSamples = NaN;
row.ExpectedNSamples = NaN;
row.NChannels = NaN;
row.ExpectedNChannels = NaN;
row.FirstSample = NaN;
row.LastSample = NaN;
row.InternalContinuityPass = false;
row.CrossChunkContinuityPass = false;
row.ReadHeaderNSamples = NaN;
row.SourceMode = '';
row.HasCorrectionInfo = false;
row.AppliedChannelGains = false;
row.AppliedMegRefCorrection = false;
row.RemovedBlockMean = false;
row.AppliedProjector = false;
row.RequiresMarcConfirmation = false;
row.MarcConfirmed = false;
row.ReadStartTime = '';
row.ReadEndTime = '';
row.ReadRuntimeSecs = NaN;
end

function row = local_timeout_row(runID, iChunk, RTConfig, expectedNChannels, Source, readStartTime, readEndTime, readRuntimeSecs)
% Build metadata for an empty chunk/timeout.
row = local_empty_metadata_row();
row.RunID = runID;
row.ChunkIndex = iChunk;
row.TimeoutFlag = true;
row.InvalidReason = 'timeout';
row.ExpectedNSamples = RTConfig.ChunkSamples;
row.ExpectedNChannels = expectedNChannels;
row.SourceMode = local_field(Source, 'Mode', '');
row.ReadStartTime = readStartTime;
row.ReadEndTime = readEndTime;
row.ReadRuntimeSecs = readRuntimeSecs;
end

function row = local_source_error_row(runID, iChunk, RTConfig, expectedNChannels, Source, readStartTime, readEndTime, readRuntimeSecs, ME)
% Build metadata for a low-level source read error.
row = local_empty_metadata_row();
row.RunID = runID;
row.ChunkIndex = iChunk;
row.InvalidChunkFlag = true;
row.InvalidReason = 'source_read_error';
row.ExpectedNSamples = RTConfig.ChunkSamples;
row.ExpectedNChannels = expectedNChannels;
row.SourceMode = local_field(Source, 'Mode', '');
row.ReadStartTime = readStartTime;
row.ReadEndTime = readEndTime;
row.ReadRuntimeSecs = readRuntimeSecs;
messageLower = lower(ME.message);
if contains(messageLower, 'samples')
    row.InvalidReason = 'source_read_error;chunk_size';
elseif contains(messageLower, 'channel')
    row.InvalidReason = 'source_read_error;channel_count';
elseif contains(messageLower, 'sample_indices') || contains(messageLower, 'sample')
    row.InvalidReason = 'source_read_error;cross_chunk_sample_gap';
end
end

function [row, messages, previousLastSample, expectedNChannels] = local_validate_chunk( ...
    chunk, Source, RTConfig, runID, iChunk, previousLastSample, expectedNChannels, ...
    readStartTime, readEndTime, readRuntimeSecs)
% Validate one non-empty chunk and return a metadata row.
row = local_empty_metadata_row();
messages = {};
row.RunID = runID;
row.ChunkIndex = iChunk;
row.ExpectedNSamples = RTConfig.ChunkSamples;
row.ExpectedNChannels = expectedNChannels;
row.SourceMode = local_field(chunk, 'SourceMode', '');
row.ReadStartTime = readStartTime;
row.ReadEndTime = readEndTime;
row.ReadRuntimeSecs = readRuntimeSecs;

hasData = isfield(chunk, 'Data') && isnumeric(chunk.Data) && ismatrix(chunk.Data);
if hasData
    row.NChannels = size(chunk.Data, 1);
    dataSamples = size(chunk.Data, 2);
else
    row.NChannels = NaN;
    dataSamples = NaN;
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'missing_data', ...
        'chunk.Data is missing or nonnumeric.');
end

if isfield(chunk, 'NSamples')
    row.NSamples = chunk.NSamples;
else
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'missing_nsamples', ...
        'chunk.NSamples is missing.');
end
if ~(row.NSamples == RTConfig.ChunkSamples) || ~(dataSamples == RTConfig.ChunkSamples)
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'chunk_size', ...
        sprintf('Expected %d samples, got chunk.NSamples=%s and data samples=%s.', ...
        RTConfig.ChunkSamples, local_num_text(row.NSamples), local_num_text(dataSamples)));
end

if isfinite(row.NChannels) && row.NChannels > 0
    if ~isfinite(expectedNChannels)
        expectedNChannels = row.NChannels;
        row.ExpectedNChannels = expectedNChannels;
    elseif row.NChannels ~= expectedNChannels
        [row, messages] = local_mark_invalid(row, messages, iChunk, 'channel_count', ...
            sprintf('Channel count changed from %d to %d.', expectedNChannels, row.NChannels));
    end
else
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'channel_count', ...
        'Channel count is missing or nonpositive.');
end

if ~isfield(chunk, 'ChannelNames') || numel(chunk.ChannelNames) ~= row.NChannels
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'channel_names', ...
        'chunk.ChannelNames is missing or does not match data channel count.');
end

if isfield(chunk, 'SampleIndices') && isnumeric(chunk.SampleIndices)
    sampleIndices = double(chunk.SampleIndices(:)');
    if ~isempty(sampleIndices)
        row.StartSample = sampleIndices(1);
        row.StopSample = sampleIndices(end);
        row.FirstSample = sampleIndices(1);
        row.LastSample = sampleIndices(end);
    end
else
    sampleIndices = [];
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'sample_indices', ...
        'chunk.SampleIndices is missing.');
end

if numel(sampleIndices) ~= RTConfig.ChunkSamples
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'sample_indices', ...
        sprintf('Expected %d sample indices, got %d.', RTConfig.ChunkSamples, numel(sampleIndices)));
end
row.InternalContinuityPass = numel(sampleIndices) == RTConfig.ChunkSamples && ...
    all(diff(sampleIndices) == 1);
if ~row.InternalContinuityPass
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'internal_sample_continuity', ...
        'Sample indices are not consecutive within chunk.');
end

if isnan(previousLastSample) || isempty(sampleIndices)
    row.CrossChunkContinuityPass = true;
elseif sampleIndices(1) == previousLastSample + 1
    row.CrossChunkContinuityPass = true;
else
    row.CrossChunkContinuityPass = false;
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'cross_chunk_sample_gap', ...
        sprintf('Sample gap: previous last sample %d, current first sample %d.', ...
        previousLastSample, sampleIndices(1)));
end

if isfield(chunk, 'SampleIndex') && ~isempty(sampleIndices) && chunk.SampleIndex ~= sampleIndices(1)
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'sample_index', ...
        'chunk.SampleIndex does not equal chunk.SampleIndices(1).');
end

sourceMode = local_field(Source, 'Mode', '');
if isfield(chunk, 'SourceMode') && ~isempty(sourceMode) && ~strcmp(chunk.SourceMode, sourceMode)
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'source_mode', ...
        'chunk.SourceMode does not match Source.Mode.');
end

if isfield(chunk, 'ReadHeaderNSamples')
    row.ReadHeaderNSamples = chunk.ReadHeaderNSamples;
end
if isfield(chunk, 'CorrectionInfo') && isstruct(chunk.CorrectionInfo)
    row = local_copy_correction_info(row, chunk.CorrectionInfo);
end

if ~isempty(sampleIndices)
    previousLastSample = sampleIndices(end);
end
end

function [row, messages] = local_mark_invalid(row, messages, iChunk, reason, message)
% Mark a row invalid and append a detailed chunk message.
row.InvalidChunkFlag = true;
if isempty(row.InvalidReason)
    row.InvalidReason = reason;
else
    row.InvalidReason = [row.InvalidReason ';' reason];
end
messages{end+1} = sprintf('Chunk %d invalid (%s): %s', iChunk, reason, message);
end

function row = local_copy_correction_info(row, CorrectionInfo)
% Copy correction flags into metadata.
row.HasCorrectionInfo = true;
row.AppliedChannelGains = local_logical_field(CorrectionInfo, 'AppliedChannelGains', false);
row.AppliedMegRefCorrection = local_logical_field(CorrectionInfo, 'AppliedMegRefCorrection', false);
row.RemovedBlockMean = local_logical_field(CorrectionInfo, 'RemovedBlockMean', false);
row.AppliedProjector = local_logical_field(CorrectionInfo, 'AppliedProjector', false);
row.RequiresMarcConfirmation = local_logical_field(CorrectionInfo, 'RequiresMarcConfirmation', false);
row.MarcConfirmed = local_logical_field(CorrectionInfo, 'MarcConfirmed', false);
end

function Preview = local_first_chunk_preview(chunk)
% Capture the first corrected chunk; save helper enforces size limits.
Preview = struct();
Preview.Data = chunk.Data;
Preview.ChannelNames = local_field(chunk, 'ChannelNames', {});
Preview.SampleIndices = local_field(chunk, 'SampleIndices', []);
end

function Summary = local_correction_summary(MetadataTable, Source)
% Summarize correction state across metadata rows.
Summary = struct();
Summary.AppliedChannelGains = any(local_table_logical(MetadataTable, 'AppliedChannelGains'));
Summary.AppliedMegRefCorrection = any(local_table_logical(MetadataTable, 'AppliedMegRefCorrection'));
Summary.RemovedBlockMean = any(local_table_logical(MetadataTable, 'RemovedBlockMean'));
Summary.AppliedProjector = any(local_table_logical(MetadataTable, 'AppliedProjector'));
Summary.RequiresMarcConfirmation = any(local_table_logical(MetadataTable, 'RequiresMarcConfirmation'));
Summary.MarcConfirmed = any(local_table_logical(MetadataTable, 'MarcConfirmed'));
Summary.CorrectionOrder = {};
Summary.Messages = {};
if isfield(Source, 'CorrectionState')
    Summary.CorrectionOrder = local_field(Source.CorrectionState, 'CorrectionOrder', {});
    Summary.Messages = local_field(Source.CorrectionState, 'Messages', {});
end
if Summary.RequiresMarcConfirmation && ~Summary.MarcConfirmed
    Summary.Messages{end+1} = ...
        'Ben-compatible correction path is candidate/unconfirmed until Marc confirms it.';
end
end

function Result = local_finalize_pass_fail(Result, RTConfig)
% Apply final pass/fail criteria before saving.
fsPass = abs(Result.Fs - 2400) <= 1e-9;
allChunksRead = Result.NReadChunks == Result.NRequestedChunks;
allPass = allChunksRead && Result.TimeoutPass && Result.NInvalidChunks == 0 && ...
    fsPass && Result.ChunkSizePass && Result.InternalChunkContinuityPass && ...
    Result.CrossChunkContinuityPass && Result.ChannelCountStablePass;

if strcmp(Result.StopReason, 'manual') && Result.NReadChunks < Result.NRequestedChunks
    Result.Pass = false;
    Result.Status = 'STOPPED';
    Result.Message = 'Live chunk smoke test stopped manually before all chunks completed.';
elseif allPass
    Result.Pass = true;
    Result.Status = 'PASS';
    Result.Message = 'Live chunk smoke test passed.';
else
    Result.Pass = false;
    if ~strcmp(Result.Status, 'STOPPED')
        Result.Status = 'FAIL';
    end
    if isempty(Result.Message)
        Result.Message = local_failure_message(Result, RTConfig, fsPass, allChunksRead);
    end
end
end

function message = local_failure_message(Result, RTConfig, fsPass, allChunksRead)
% Build a specific failure message.
if strcmp(Result.StopReason, 'timeout_limit_exceeded')
    message = sprintf('Live chunk smoke test failed: timeout limit exceeded (%d > %d).', ...
        Result.NTimeouts, RTConfig.LiveChunkSmokeTest.MaxTimeouts);
elseif Result.NInvalidChunks > 0 && ~Result.CrossChunkContinuityPass
    message = 'Live chunk smoke test failed: sample continuity gap detected.';
elseif Result.NInvalidChunks > 0 && ~Result.ChannelCountStablePass
    message = 'Live chunk smoke test failed: channel count changed across chunks.';
elseif Result.NInvalidChunks > 0 && ~Result.ChunkSizePass
    message = sprintf('Live chunk smoke test failed: expected %d samples but at least one chunk had a different size.', ...
        RTConfig.ChunkSamples);
elseif strcmp(Result.StopReason, 'source_read_error')
    message = 'Live chunk smoke test failed: source read error.';
elseif ~fsPass
    message = 'Live chunk smoke test failed: Fs did not match 2400 Hz.';
elseif ~allChunksRead
    message = 'Live chunk smoke test failed: not all requested chunks were read.';
else
    message = 'Live chunk smoke test failed.';
end
end

function values = local_table_logical(T, fieldName)
% Return logical column or false for empty/missing tables.
if isempty(T) || ~ismember(fieldName, T.Properties.VariableNames)
    values = false;
else
    values = T.(fieldName);
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

function value = local_logical_field(S, fieldName, defaultValue)
% Read optional logical field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && islogical(S.(fieldName)) && isscalar(S.(fieldName))
    value = S.(fieldName);
end
end

function textValue = local_num_text(value)
% Format numeric diagnostic values.
if isempty(value) || ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    textValue = 'NaN';
else
    textValue = num2str(value);
end
end

function value = local_run_id()
% Generate a compact run identifier.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
else
    value = datestr(now, 'yyyymmdd_HHMMSS');
end
end

function value = local_now_text()
% Generate a stable timestamp string.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
else
    value = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
end
