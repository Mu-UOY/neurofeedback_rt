function Result = nf_run_live_rt_dry_run(RTConfig)
% NF_RUN_LIVE_RT_DRY_RUN Run repeated live chunks through the RT core.
%
% USAGE:  Result = nf_run_live_rt_dry_run()
%         Result = nf_run_live_rt_dry_run(RTConfig)
%
% DESCRIPTION:
%     Step 3C live RT dry run. Reads repeated live FieldTrip chunks through
%     the public source dispatchers, processes them with the validated RT
%     core, verifies dry-run invariants, and saves a compact report.

%% ===== PREPARE CONFIG =====
% Preserve operator-provided connection and output settings.
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_live_config();
end
Modes = nf_modes();
RTConfig.Session.Mode = Modes.Session.LiveRTDryRun;
RTConfig.Source.Mode = Modes.Source.LiveFieldTrip;
RTConfig.Source.LiveAdapter = Modes.LiveAdapter.BenFieldTrip;
RTConfig.Feedback.Mode = Modes.Feedback.None;

requestedProjectRoot = '';
if isfield(RTConfig, 'Paths') && isfield(RTConfig.Paths, 'ProjectRoot')
    requestedProjectRoot = RTConfig.Paths.ProjectRoot;
end

RTConfig = nf_finalize_config(RTConfig);
if ~isempty(requestedProjectRoot)
    RTConfig.Paths.ProjectRoot = requestedProjectRoot;
end

NChunks = RTConfig.LiveRTDryRun.NChunks;
Result = local_empty_result(RTConfig, NChunks);
RTConfig.SessionMetadata.RunID = Result.RunID;

%% ===== INITIALIZE SOURCE, SPATIAL, RT, AND SAFETY =====
% Source and chunk reads intentionally go through public dispatchers.
Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
Result = local_populate_source_fields(Result, Source);

Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);
RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.CombinedMatrix = Spatial.CombinedMatrix;
RTConfig.Spatial.NChannels = size(Spatial.CombinedMatrix, 2);
RTConfig.Spatial.Prepared = Spatial;

Result.Spatial = Spatial;
Result.NSignals = size(Spatial.CombinedMatrix, 1);
Result.OutputSignalNames = Spatial.OutputSignalNames;

RT = nf_rt_prepare(RTConfig);
Result.RTPrepared = true;
Result.RTHasBaseline = local_logical_field(RT, 'HasBaseline', false);

Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveRTDryRun);

%% ===== READ AND PROCESS CHUNKS =====
% Each non-empty valid chunk is handed directly to the RT processing core.
Measures = repmat(nf_measure_empty(), 0, 1);
metadataRows = repmat(local_empty_metadata_row(), 0, 1);
previousLastSample = NaN;

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
    [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    readRuntimeSecs = toc(tRead);
    readEndTime = local_now_text();

    processingStartTime = '';
    processingEndTime = '';
    processingRuntimeSecs = NaN;
    Measure = nf_measure_empty();

    if isempty(chunk)
        Result.NTimeouts = Result.NTimeouts + 1;
        row = local_timeout_row(Result.RunID, iChunk, RTConfig, Source, ...
            readStartTime, readEndTime, readRuntimeSecs);
        metadataRows(end+1) = row; %#ok<AGROW>
        if Result.NTimeouts > RTConfig.LiveRTDryRun.MaxTimeouts
            Result.StopReason = 'timeout_limit_exceeded';
            Result.Messages{end+1} = sprintf('Timeout limit exceeded after chunk %d.', iChunk);
            break;
        end
    else
        Result.NReadChunks = Result.NReadChunks + 1;
        [row, invalidMessages, previousLastSample] = local_validate_chunk( ...
            chunk, RTConfig, Result.RunID, iChunk, previousLastSample, ...
            readStartTime, readEndTime, readRuntimeSecs);

        if row.InvalidChunkFlag
            Result.NInvalidChunks = Result.NInvalidChunks + 1;
            Result.Messages = [Result.Messages, invalidMessages];
            metadataRows(end+1) = row; %#ok<AGROW>
        else
            processingStartTime = local_now_text();
            tProcess = tic;
            try
                [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
                processingRuntimeSecs = toc(tProcess);
                processingEndTime = local_now_text();
                Result.NProcessedChunks = Result.NProcessedChunks + 1;
                Measures(end+1) = Measure; %#ok<AGROW>
            catch ME
                processingRuntimeSecs = toc(tProcess);
                processingEndTime = local_now_text();
                Result.NInvalidChunks = Result.NInvalidChunks + 1;
                Result.StopReason = 'processing_error';
                Result.ErrorMessage = ME.message;
                Result.Messages{end+1} = sprintf('Chunk %d processing error: %s', ...
                    iChunk, ME.message);
                row.InvalidChunkFlag = true;
                row.InvalidReason = local_append_reason(row.InvalidReason, 'processing_error');
            end

            row = local_attach_measure_metadata(row, Measure, RTConfig, processingStartTime, ...
                processingEndTime, processingRuntimeSecs);
            metadataRows(end+1) = row; %#ok<AGROW>

            if Measure.IsValid && isfinite(Measure.Power)
                Result.NValidMeasures = Result.NValidMeasures + 1;
                if isnan(Result.FirstValidMeasureChunk)
                    Result.FirstValidMeasureChunk = iChunk;
                end
            end
        end
    end

    [stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
    if stopRequested
        Result.StopReason = 'manual';
        if Result.NProcessedChunks < Result.NRequestedChunks
            Result.Status = 'STOPPED';
            Result.Messages{end+1} = 'Manual stop requested after chunk handling.';
        end
        break;
    end
    if nf_safety_hard_failsafe_exceeded(Safety)
        Result.StopReason = 'hard_failsafe';
        Result.Messages{end+1} = 'Hard failsafe exceeded after chunk handling.';
        break;
    end

    if strcmp(Result.StopReason, 'processing_error')
        break;
    end
end

%% ===== FINALIZE RESULT =====
% Summaries are computed before saving so MAT/TXT/CSV agree.
Result.NMeasures = numel(Measures);
Result.MetadataTable = local_rows_to_table(metadataRows);
Result.MeasureTable = local_measures_table(Measures, RTConfig);
Result.RTSummary = local_rt_summary(RT, RTConfig, Result);
Result = local_finalize_checks(Result, Measures, RT, RTConfig);

Result = nf_save_live_rt_dry_run(Result, RTConfig, Source, RT, Measures);

[stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
if stopRequested && isempty(Result.StopReason)
    Result.StopReason = 'manual';
    Result.Status = 'STOPPED';
    Result.Pass = false;
end
if nf_safety_hard_failsafe_exceeded(Safety)
    Result.StopReason = 'hard_failsafe';
    Result.Status = 'FAIL';
    Result.Pass = false;
end
nf_safety_shutdown(Safety);

end

function Result = local_empty_result(RTConfig, NChunks)
% Create the stable live RT dry-run Result schema.
Result = struct();
Result.Type = 'live_rt_dry_run';
Result.Pass = false;
Result.Status = 'FAIL';
Result.Message = '';
Result.StopReason = '';
Result.ErrorMessage = '';
Result.RunID = local_run_id();
Result.SessionDir = '';
Result.ReportMatPath = '';
Result.ReportTextPath = '';
Result.MeasureCsvPath = '';
Result.ChunkMetaCsvPath = '';
Result.NRequestedChunks = NChunks;
Result.NReadChunks = 0;
Result.NProcessedChunks = 0;
Result.NTimeouts = 0;
Result.NInvalidChunks = 0;
Result.NMeasures = 0;
Result.NValidMeasures = 0;
Result.FirstValidMeasureChunk = NaN;
Result.Fs = NaN;
Result.ExpectedFs = 2400;
Result.ChunkSamples = RTConfig.ChunkSamples;
Result.ExpectedChunkSamples = 480;
Result.PowerWindowSamples = RTConfig.PowerWindowSamples;
Result.ExpectedPowerWindowSamples = 4800;
Result.NChannels = NaN;
Result.NSignals = NaN;
Result.ChannelNames = {};
Result.OutputSignalNames = {};
Result.Spatial = struct();
Result.RTHasBaseline = false;
Result.RTPrepared = false;
Result.FilterStateUpdatedPass = false;
Result.BufferFilledPass = false;
Result.ValidMeasureAppearedPass = false;
Result.PowerWindowLengthPass = false;
Result.FeedbackUnmappedPass = false;
Result.NoBaselinePass = false;
Result.TimingPass = true;
Result.MeanProcessingSeconds = NaN;
Result.MaxProcessingSeconds = NaN;
Result.MetadataTable = table();
Result.MeasureTable = table();
Result.RTSummary = struct();
Result.Messages = {};
end

function Result = local_populate_source_fields(Result, Source)
% Copy source fields that are independent of processing.
if isfield(Source, 'Fs')
    Result.Fs = Source.Fs;
end
if isfield(Source, 'ChannelNamesAfterCorrection') && ~isempty(Source.ChannelNamesAfterCorrection)
    Result.ChannelNames = local_cellstr(Source.ChannelNamesAfterCorrection);
elseif isfield(Source, 'ChannelNames')
    Result.ChannelNames = local_cellstr(Source.ChannelNames);
end
Result.NChannels = numel(Result.ChannelNames);
end

function row = local_empty_metadata_row()
% Stable metadata schema: one row per attempted live chunk.
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
row.NSignals = NaN;
row.ReadHeaderNSamples = NaN;
row.SourceMode = '';
row.MeasureIsValid = false;
row.MeasureInvalidReason = '';
row.MeasurePower = NaN;
row.MeasureZRaw = NaN;
row.MeasureZClipped = NaN;
row.MeasureZSmoothed = NaN;
row.MeasureFeedbackValue = NaN;
row.WindowStartSample = NaN;
row.WindowEndSample = NaN;
row.WindowLengthSamples = NaN;
row.PowerWindowLengthPass = false;
row.ReadStartTime = '';
row.ReadEndTime = '';
row.ProcessingStartTime = '';
row.ProcessingEndTime = '';
row.ReadRuntimeSecs = NaN;
row.ProcessingRuntimeSecs = NaN;
end

function row = local_timeout_row(runID, iChunk, RTConfig, Source, readStartTime, readEndTime, readRuntimeSecs)
% Build metadata for an empty chunk.
row = local_empty_metadata_row();
row.RunID = runID;
row.ChunkIndex = iChunk;
row.TimeoutFlag = true;
row.InvalidReason = 'timeout';
row.ExpectedNSamples = RTConfig.ChunkSamples;
row.SourceMode = local_field(Source, 'Mode', '');
row.ReadStartTime = readStartTime;
row.ReadEndTime = readEndTime;
row.ReadRuntimeSecs = readRuntimeSecs;
end

function [row, messages, previousLastSample] = local_validate_chunk( ...
    chunk, RTConfig, runID, iChunk, previousLastSample, readStartTime, readEndTime, readRuntimeSecs)
% Validate one chunk before handing it to the RT core.
row = local_empty_metadata_row();
messages = {};
row.RunID = runID;
row.ChunkIndex = iChunk;
row.ExpectedNSamples = RTConfig.ChunkSamples;
row.SourceMode = local_field(chunk, 'SourceMode', '');
row.ReadStartTime = readStartTime;
row.ReadEndTime = readEndTime;
row.ReadRuntimeSecs = readRuntimeSecs;

hasData = isfield(chunk, 'Data') && isnumeric(chunk.Data) && ismatrix(chunk.Data);
if hasData
    row.NChannels = size(chunk.Data, 1);
    dataSamples = size(chunk.Data, 2);
else
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

sampleIndices = [];
if isfield(chunk, 'SampleIndices') && isnumeric(chunk.SampleIndices)
    sampleIndices = double(chunk.SampleIndices(:)');
    if ~isempty(sampleIndices)
        row.StartSample = sampleIndices(1);
        row.StopSample = sampleIndices(end);
    end
elseif isfield(chunk, 'SampleIndex') && isfield(chunk, 'NSamples')
    sampleIndices = chunk.SampleIndex:(chunk.SampleIndex + chunk.NSamples - 1);
    row.StartSample = sampleIndices(1);
    row.StopSample = sampleIndices(end);
end

if numel(sampleIndices) ~= RTConfig.ChunkSamples || any(diff(sampleIndices) ~= 1)
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'sample_continuity', ...
        'Sample indices are missing or nonconsecutive within chunk.');
end
if isfinite(previousLastSample) && ~isempty(sampleIndices) && sampleIndices(1) ~= previousLastSample + 1
    [row, messages] = local_mark_invalid(row, messages, iChunk, 'cross_chunk_sample_gap', ...
        sprintf('Previous last sample %d, current first sample %d.', ...
        previousLastSample, sampleIndices(1)));
end
if ~isempty(sampleIndices)
    previousLastSample = sampleIndices(end);
end
end

function [row, messages] = local_mark_invalid(row, messages, iChunk, reason, message)
% Mark a row invalid and append one diagnostic message.
row.InvalidChunkFlag = true;
row.InvalidReason = local_append_reason(row.InvalidReason, reason);
messages{end+1} = sprintf('Chunk %d invalid (%s): %s', iChunk, reason, message);
end

function row = local_attach_measure_metadata(row, Measure, RTConfig, processingStartTime, ...
    processingEndTime, processingRuntimeSecs)
% Attach RT output fields to the chunk metadata row.
row.ProcessingStartTime = processingStartTime;
row.ProcessingEndTime = processingEndTime;
row.ProcessingRuntimeSecs = processingRuntimeSecs;
if isempty(Measure) || ~isstruct(Measure)
    return;
end
row.NSignals = numel(local_field(Measure, 'PowerPerSignal', []));
row.MeasureIsValid = local_logical_field(Measure, 'IsValid', false);
row.MeasureInvalidReason = local_field(Measure, 'InvalidReason', '');
row.MeasurePower = local_numeric_field(Measure, 'Power', NaN);
row.MeasureZRaw = local_numeric_field(Measure, 'ZRaw', NaN);
row.MeasureZClipped = local_numeric_field(Measure, 'ZClipped', NaN);
row.MeasureZSmoothed = local_numeric_field(Measure, 'ZSmoothed', NaN);
row.MeasureFeedbackValue = local_numeric_field(Measure, 'FeedbackValue', NaN);
row.WindowStartSample = local_numeric_field(Measure, 'WindowStartSample', NaN);
row.WindowEndSample = local_numeric_field(Measure, 'WindowEndSample', NaN);
if isfinite(row.WindowStartSample) && isfinite(row.WindowEndSample)
    row.WindowLengthSamples = row.WindowEndSample - row.WindowStartSample + 1;
    row.PowerWindowLengthPass = row.WindowLengthSamples == RTConfig.PowerWindowSamples;
end
end

function T = local_rows_to_table(rows)
% Convert metadata rows to a table with stable columns.
if isempty(rows)
    T = struct2table(repmat(local_empty_metadata_row(), 0, 1));
else
    T = struct2table(rows);
end
end

function T = local_measures_table(Measures, RTConfig)
% Convert measures to a stable table, keeping failures explicit.
try
    T = nf_measures_to_table(Measures, RTConfig);
catch
    T = table();
end
end

function Summary = local_rt_summary(RT, RTConfig, Result)
% Build a compact RT state summary for the saved report.
Summary = struct();
Summary.PreparedAt = local_field(RT, 'PreparedAt', '');
Summary.SourceMode = local_field(RT, 'SourceMode', '');
Summary.HasBaseline = local_logical_field(RT, 'HasBaseline', false);
Summary.SpatialMode = local_get_nested_text(RTConfig, {'Spatial','Mode'}, '');
Summary.SpatialMatrixSource = local_get_nested_text(RTConfig, {'Spatial','MatrixSource'}, '');
Summary.NChannels = Result.NChannels;
Summary.NSignals = Result.NSignals;
Summary.FilterType = local_get_nested_text(RT, {'Filter','Type'}, '');
Summary.FilterSamplesProcessed = local_get_nested_numeric(RT, {'Filter','SamplesProcessed'}, NaN);
Summary.FilterWarmupComplete = local_get_nested_logical(RT, {'Filter','WarmupComplete'}, false);
Summary.BufferCapacity = local_get_nested_numeric(RT, {'Buffer','Capacity'}, NaN);
Summary.BufferTotalWritten = local_get_nested_numeric(RT, {'Buffer','TotalWritten'}, NaN);
Summary.SampleCounterChunkCount = local_get_nested_numeric(RT, {'SampleCounter','ChunkCount'}, NaN);
Summary.SampleCounterTotalReceived = local_get_nested_numeric(RT, {'SampleCounter','TotalReceived'}, NaN);
Summary.SampleCounterTotalValid = local_get_nested_numeric(RT, {'SampleCounter','TotalValid'}, NaN);
Summary.SampleCounterLastSampleIndex = local_get_nested_numeric(RT, {'SampleCounter','LastSampleIndex'}, NaN);
Summary.ConfigHash = local_field(RT, 'ConfigHash', '');
end

function Result = local_finalize_checks(Result, Measures, RT, RTConfig)
% Apply pass/fail criteria for Step 3C.
processingTimes = local_get_nested_numeric_vector(RT, {'Timing','ChunkProcessingTimes'});
if ~isempty(processingTimes)
    Result.MeanProcessingSeconds = mean(processingTimes);
    Result.MaxProcessingSeconds = max(processingTimes);
end

Result.FilterStateUpdatedPass = local_get_nested_numeric(RT, {'Filter','SamplesProcessed'}, 0) > 0;
Result.BufferFilledPass = local_get_nested_numeric(RT, {'Buffer','TotalWritten'}, 0) >= RTConfig.PowerWindowSamples;
Result.ValidMeasureAppearedPass = Result.NValidMeasures >= 1;
Result.PowerWindowLengthPass = local_power_window_length_pass(Measures, RTConfig, Result);
Result.FeedbackUnmappedPass = local_feedback_unmapped_pass(Measures);
Result.NoBaselinePass = ~local_logical_field(RT, 'HasBaseline', false);

if RTConfig.LiveRTDryRun.RequireTimingPass && isfinite(Result.MaxProcessingSeconds)
    Result.TimingPass = Result.MaxProcessingSeconds <= RTConfig.LiveRTDryRun.TimingWarningSeconds;
elseif isfinite(Result.MeanProcessingSeconds) && ...
        Result.MeanProcessingSeconds > RTConfig.LiveRTDryRun.TimingWarningSeconds
    Result.Messages{end+1} = sprintf('Mean processing time %.4f s exceeded warning threshold %.4f s.', ...
        Result.MeanProcessingSeconds, RTConfig.LiveRTDryRun.TimingWarningSeconds);
end

allChunksProcessed = Result.NProcessedChunks == Result.NRequestedChunks;
timeoutPass = Result.NTimeouts <= RTConfig.LiveRTDryRun.MaxTimeouts;
fsPass = abs(Result.Fs - Result.ExpectedFs) <= 1e-9;
chunkPass = Result.ChunkSamples == Result.ExpectedChunkSamples;
windowPass = Result.PowerWindowSamples == Result.ExpectedPowerWindowSamples;
validPass = ~RTConfig.LiveRTDryRun.RequireAtLeastOneValidMeasure || Result.ValidMeasureAppearedPass;
dryValuePass = ~RTConfig.LiveRTDryRun.RequireFeedbackNaN || Result.FeedbackUnmappedPass;
noBaselinePass = ~RTConfig.LiveRTDryRun.RequireNoBaseline || Result.NoBaselinePass;
timingPass = ~RTConfig.LiveRTDryRun.RequireTimingPass || Result.TimingPass;

allPass = allChunksProcessed && timeoutPass && Result.NInvalidChunks == 0 && ...
    fsPass && chunkPass && windowPass && Result.RTPrepared && ...
    Result.FilterStateUpdatedPass && Result.BufferFilledPass && ...
    Result.PowerWindowLengthPass && validPass && dryValuePass && ...
    noBaselinePass && timingPass;

if strcmp(Result.StopReason, 'manual') && ~allChunksProcessed
    Result.Pass = false;
    Result.Status = 'STOPPED';
    Result.Message = 'Live RT dry run stopped manually before all requested chunks completed.';
elseif allPass
    Result.Pass = true;
    Result.Status = 'PASS';
    Result.Message = 'Live RT dry run passed.';
else
    Result.Pass = false;
    if ~strcmp(Result.Status, 'STOPPED')
        Result.Status = 'FAIL';
    end
    if isempty(Result.Message)
        Result.Message = local_failure_message(Result, RTConfig, allChunksProcessed, timeoutPass, fsPass);
    end
end
end

function tf = local_power_window_length_pass(Measures, RTConfig, Result)
% Require every valid measure with window fields to use the configured window.
validMeasures = Measures(arrayfun(@(m) local_logical_field(m, 'IsValid', false), Measures));
if isempty(validMeasures)
    tf = ~RTConfig.LiveRTDryRun.RequireAtLeastOneValidMeasure;
    return;
end
tf = true;
for iMeasure = 1:numel(validMeasures)
    startSample = local_numeric_field(validMeasures(iMeasure), 'WindowStartSample', NaN);
    endSample = local_numeric_field(validMeasures(iMeasure), 'WindowEndSample', NaN);
    if isfinite(startSample) && isfinite(endSample)
        tf = tf && ((endSample - startSample + 1) == RTConfig.PowerWindowSamples);
    end
end
if Result.NValidMeasures < 1 && RTConfig.LiveRTDryRun.RequireAtLeastOneValidMeasure
    tf = false;
end
end

function tf = local_feedback_unmapped_pass(Measures)
% Check display-value fields stay unassigned by this runner.
tf = true;
for iMeasure = 1:numel(Measures)
    m = Measures(iMeasure);
    tf = tf && isnan(local_numeric_field(m, 'FeedbackValue', NaN));
    tf = tf && isnan(local_numeric_field(m, 'FeedbackTargetRadiusPx', NaN));
    tf = tf && isnan(local_numeric_field(m, 'FeedbackDisplayRadiusPx', NaN));
    tf = tf && isnan(local_numeric_field(m, 'FeedbackOuterRadiusPx', NaN));
    tf = tf && isempty(local_field(m, 'FeedbackDisplayType', ''));
    tf = tf && isnan(local_numeric_field(m, 'FeedbackDisplayTime', NaN));
end
end

function message = local_failure_message(Result, RTConfig, allChunksProcessed, timeoutPass, fsPass)
% Build a concise failure message.
if strcmp(Result.StopReason, 'timeout_limit_exceeded') || ~timeoutPass
    message = sprintf('Live RT dry run failed: timeout limit exceeded (%d > %d).', ...
        Result.NTimeouts, RTConfig.LiveRTDryRun.MaxTimeouts);
elseif Result.NInvalidChunks > 0
    message = 'Live RT dry run failed: at least one chunk or processing call was invalid.';
elseif ~fsPass
    message = 'Live RT dry run failed: Fs did not match 2400 Hz.';
elseif ~allChunksProcessed
    message = 'Live RT dry run failed: not all requested chunks were processed.';
elseif ~Result.ValidMeasureAppearedPass
    message = 'Live RT dry run failed: no valid measures appeared after warmup.';
elseif ~Result.FeedbackUnmappedPass
    message = 'Live RT dry run failed: dry-run display fields were assigned.';
elseif ~Result.NoBaselinePass
    message = 'Live RT dry run failed: RT state unexpectedly reports baseline availability.';
else
    message = 'Live RT dry run failed.';
end
end

function reason = local_append_reason(reason, newReason)
% Append semicolon-separated invalid reasons.
if isempty(reason)
    reason = newReason;
else
    reason = [reason ';' newReason];
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
% Read optional scalar logical-like field.
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

function value = local_numeric_field(S, fieldName, defaultValue)
% Read optional scalar numeric-like field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    raw = S.(fieldName);
    if isnumeric(raw) && isscalar(raw)
        value = double(raw);
    elseif islogical(raw) && isscalar(raw)
        value = double(raw);
    end
end
end

function value = local_get_nested_text(S, path, defaultValue)
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
elseif isnumeric(cursor) || islogical(cursor)
    value = num2str(cursor(1));
end
end

function value = local_get_nested_numeric(S, path, defaultValue)
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
elseif islogical(cursor) && isscalar(cursor)
    value = double(cursor);
end
end

function value = local_get_nested_logical(S, path, defaultValue)
% Read optional nested logical-like scalar.
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
elseif isnumeric(cursor) && isscalar(cursor) && isfinite(cursor)
    value = cursor ~= 0;
end
end

function values = local_get_nested_numeric_vector(S, path)
% Read optional nested numeric vector.
values = [];
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if isnumeric(cursor)
    values = double(cursor(:));
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
