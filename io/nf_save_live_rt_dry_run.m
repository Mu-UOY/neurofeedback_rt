function Result = nf_save_live_rt_dry_run(Result, RTConfig, Source, RT, Measures)
% NF_SAVE_LIVE_RT_DRY_RUN Save Step 3C live RT dry-run reports.
%
% USAGE:  Result = nf_save_live_rt_dry_run(Result, RTConfig, Source, RT, Measures)
%
% DESCRIPTION:
%     Creates one live_rt_dry_run session folder and writes the formal MAT,
%     TXT, measure CSV, and chunk metadata CSV report.

%% ===== PREPARE SESSION =====
% Session ownership for Step 3C lives in this save helper.
Session = nf_make_session_output_dir(RTConfig, 'live_rt_dry_run');
Result.SessionDir = Session.SessionDir;
Result.ReportMatPath = fullfile(Session.ReportsDir, 'live_rt_dry_run.mat');
Result.ReportTextPath = fullfile(Session.ReportsDir, 'live_rt_dry_run.txt');
Result.MeasureCsvPath = fullfile(Session.ReportsDir, 'live_rt_dry_run_measures.csv');
Result.ChunkMetaCsvPath = fullfile(Session.ReportsDir, 'live_rt_dry_run_chunk_metadata.csv');

%% ===== PREPARE TABLES =====
% CSV schemas stay stable even when no rows were emitted.
if isfield(Result, 'MeasureTable') && ~isempty(Result.MeasureTable)
    MeasureTable = Result.MeasureTable;
else
    MeasureTable = nf_measures_to_table(Measures, RTConfig);
    Result.MeasureTable = MeasureTable;
end

if isfield(Result, 'MetadataTable') && ~isempty(Result.MetadataTable)
    MetadataTable = Result.MetadataTable;
else
    MetadataTable = table();
    Result.MetadataTable = MetadataTable;
end

%% ===== SAVE MAT AND CSV =====
% Keep MAT contents explicit and avoid serializing connection test handles.
RTConfig = local_config_for_save(RTConfig);
save(Result.ReportMatPath, 'Result', 'RTConfig', 'Source', 'RT', 'Measures');
writetable(MeasureTable, Result.MeasureCsvPath);
writetable(MetadataTable, Result.ChunkMetaCsvPath);

%% ===== SAVE TEXT REPORT =====
% The text report is the MEG-room-facing summary.
fid = fopen(Result.ReportTextPath, 'w');
if fid < 0
    error('Could not open live RT dry-run text report: %s', Result.ReportTextPath);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Live RT dry run\n');
fprintf(fid, 'RunID: %s\n', local_text(Result.RunID));
fprintf(fid, 'Source mode: %s\n', local_text(local_field(Source, 'Mode', '')));
fprintf(fid, 'Live adapter: %s\n', local_text(local_field(Source, 'LiveAdapter', '')));
fprintf(fid, 'Host: %s\n', local_text(local_nested(Source, {'ResolvedConnection','Host'}, '')));
fprintf(fid, 'Port: %s\n', local_text(local_nested(Source, {'ResolvedConnection','Port'}, [])));
fprintf(fid, 'TestBufferFcn used: %s\n', local_bool(local_nested(Source, {'ResolvedConnection','UsedTestHook'}, false)));
fprintf(fid, 'Fs: %s\n', local_text(Result.Fs));
fprintf(fid, 'Expected Fs: %s\n', local_text(Result.ExpectedFs));
fprintf(fid, 'ChunkSamples: %s\n', local_text(Result.ChunkSamples));
fprintf(fid, 'Expected ChunkSamples: %s\n', local_text(Result.ExpectedChunkSamples));
fprintf(fid, 'PowerWindowSamples: %s\n', local_text(Result.PowerWindowSamples));
fprintf(fid, 'Expected PowerWindowSamples: %s\n', local_text(Result.ExpectedPowerWindowSamples));
fprintf(fid, 'N requested chunks: %d\n', Result.NRequestedChunks);
fprintf(fid, 'N read chunks: %d\n', Result.NReadChunks);
fprintf(fid, 'N processed chunks: %d\n', Result.NProcessedChunks);
fprintf(fid, 'N timeouts: %d\n', Result.NTimeouts);
fprintf(fid, 'MaxTimeouts: %d\n', RTConfig.LiveRTDryRun.MaxTimeouts);
fprintf(fid, 'N invalid chunks: %d\n', Result.NInvalidChunks);
fprintf(fid, 'N valid measures: %d\n', Result.NValidMeasures);
fprintf(fid, 'First valid measure chunk: %s\n', local_text(Result.FirstValidMeasureChunk));
fprintf(fid, 'N channels: %s\n', local_text(Result.NChannels));
fprintf(fid, 'N signals: %s\n', local_text(Result.NSignals));
fprintf(fid, 'Spatial matrix source: %s\n', local_text(local_nested(Result, {'Spatial','MatrixSource'}, '')));
if local_nested(Result, {'Spatial','IsTechnicalFallback'}, false)
    fprintf(fid, 'Spatial fallback warning: Technical fallback matrix used; do not claim IPS neurofeedback.\n');
end
fprintf(fid, 'RT prepared: %s\n', local_passfail(Result.RTPrepared));
fprintf(fid, 'Filter state updated: %s\n', local_passfail(Result.FilterStateUpdatedPass));
fprintf(fid, 'Buffer filled: %s\n', local_passfail(Result.BufferFilledPass));
fprintf(fid, 'Power window length: %s\n', local_passfail(Result.PowerWindowLengthPass));
fprintf(fid, 'Feedback unmapped: %s\n', local_passfail(Result.FeedbackUnmappedPass));
fprintf(fid, 'No baseline: %s\n', local_passfail(Result.NoBaselinePass));
fprintf(fid, 'Mean processing seconds: %s\n', local_text(Result.MeanProcessingSeconds));
fprintf(fid, 'Max processing seconds: %s\n', local_text(Result.MaxProcessingSeconds));
fprintf(fid, 'Timing: %s\n', local_passfail(Result.TimingPass));
if isfinite(Result.MeanProcessingSeconds) && ...
        Result.MeanProcessingSeconds > RTConfig.LiveRTDryRun.TimingWarningSeconds
    fprintf(fid, 'Timing warning: mean processing exceeded %.4f seconds.\n', ...
        RTConfig.LiveRTDryRun.TimingWarningSeconds);
end
fprintf(fid, 'Final status: %s\n', local_text(Result.Status));
fprintf(fid, 'Final PASS/FAIL: %s\n', local_passfail(Result.Pass));
fprintf(fid, 'StopReason: %s\n', local_text(Result.StopReason));
fprintf(fid, 'Recommendation: %s\n', local_recommendation(Result));
fprintf(fid, 'Messages:\n');
local_print_messages(fid, Result.Messages);

clear cleanupObj

end

function RTConfig = local_config_for_save(RTConfig)
% Avoid serializing function handles and captured test workspaces.
if isfield(RTConfig, 'Source') && isfield(RTConfig.Source, 'FieldTrip') && ...
        isfield(RTConfig.Source.FieldTrip, 'TestBufferFcn')
    RTConfig.Source.FieldTrip.TestBufferFcn = [];
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

function value = local_nested(S, path, defaultValue)
% Read nested field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
value = cursor;
end

function textValue = local_text(value)
% Convert scalar values to text.
if isempty(value)
    textValue = '';
elseif isnumeric(value) && isscalar(value)
    textValue = num2str(value);
elseif islogical(value) && isscalar(value)
    textValue = local_bool(value);
elseif ischar(value)
    textValue = value;
elseif isstring(value)
    textValue = char(value);
else
    textValue = '<non-scalar>';
end
end

function textValue = local_bool(value)
% Format logical-like values.
textValue = 'false';
if (islogical(value) && isscalar(value) && value) || ...
        (isnumeric(value) && isscalar(value) && value ~= 0)
    textValue = 'true';
end
end

function textValue = local_passfail(value)
% Format pass/fail flags.
if (islogical(value) && isscalar(value) && value) || ...
        (isnumeric(value) && isscalar(value) && value ~= 0)
    textValue = 'PASS';
else
    textValue = 'FAIL';
end
end

function local_print_messages(fid, messages)
% Print messages line by line.
messages = local_cellstr(messages);
if isempty(messages)
    fprintf(fid, '  <none>\n');
    return;
end
for iMessage = 1:numel(messages)
    fprintf(fid, '  %s\n', messages{iMessage});
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

function recommendation = local_recommendation(Result)
% Return a concise next-step recommendation.
combinedText = lower([local_text(Result.Message) ' ' strjoin(local_cellstr(Result.Messages), ' ')]);
if Result.Pass
    recommendation = 'Proceed to MEG-room Step 3C validation, then Step 3D only after live RT dry run is clean.';
elseif strcmp(Result.StopReason, 'timeout_limit_exceeded') || contains(combinedText, 'timeout')
    recommendation = 'Check FieldTrip buffer host/port, acquisition status, and wait_dat/get_dat indexing.';
elseif contains(combinedText, 'spatial') || contains(combinedText, 'combinedmatrix') || contains(combinedText, 'channel')
    recommendation = 'Fix CombinedMatrix/fallback channel contract before RT dry run.';
elseif contains(combinedText, 'valid measures') || contains(combinedText, 'warmup') || contains(combinedText, 'window')
    recommendation = 'Inspect filter warmup, buffer fill, sample continuity, and power-window rejection.';
elseif contains(combinedText, 'display fields') || contains(combinedText, 'unmapped')
    recommendation = 'Remove feedback mapping/drawing from Step 3C dry run.';
elseif contains(combinedText, 'baseline')
    recommendation = 'Remove baseline loading/creation from Step 3C dry run.';
else
    recommendation = 'Resolve live RT dry-run failures before proceeding.';
end
end
