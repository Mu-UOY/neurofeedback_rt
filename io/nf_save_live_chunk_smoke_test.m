function Result = nf_save_live_chunk_smoke_test(Result, RTConfig, Source, FirstChunkPreview)
% NF_SAVE_LIVE_CHUNK_SMOKE_TEST Save Step 3B live chunk smoke-test reports.
%
% USAGE:  Result = nf_save_live_chunk_smoke_test(Result, RTConfig, Source, FirstChunkPreview)
%
% DESCRIPTION:
%     Creates one live_chunk_smoke_test session folder and writes the formal
%     acquisition-only smoke-test MAT, TXT, CSV, and optional small preview.

%% ===== PREPARE SESSION =====
% Session ownership for Step 3B lives in this save helper.
Session = nf_make_session_output_dir(RTConfig, 'live_chunk_smoke_test');
Result.SessionDir = Session.SessionDir;
Result.ReportMatPath = fullfile(Session.ReportsDir, 'live_chunk_smoke_test.mat');
Result.ReportTextPath = fullfile(Session.ReportsDir, 'live_chunk_smoke_test.txt');
Result.MetadataCsvPath = fullfile(Session.ReportsDir, 'live_chunk_metadata.csv');
Result.FirstChunkPreviewPath = '';

if nargin < 4
    FirstChunkPreview = [];
end

%% ===== PREPARE METADATA =====
% CSV output is always metadata only.
MetadataTable = Result.MetadataTable;
if isempty(MetadataTable)
    MetadataTable = table();
end

%% ===== PREPARE FIRST-CHUNK PREVIEW =====
% Save a bounded corrected-data preview only when requested.
savePreview = isfield(RTConfig, 'LiveChunkSmokeTest') && ...
    isfield(RTConfig.LiveChunkSmokeTest, 'SaveFirstChunkPreview') && ...
    RTConfig.LiveChunkSmokeTest.SaveFirstChunkPreview && ~isempty(FirstChunkPreview);
if savePreview
    FirstChunkPreview = local_limit_preview(FirstChunkPreview, RTConfig);
    Result.FirstChunkPreviewPath = fullfile(Session.ReportsDir, 'first_chunk_preview.mat');
    save(Result.FirstChunkPreviewPath, 'FirstChunkPreview');
end

%% ===== SAVE MAT AND CSV =====
% Keep MAT contents explicit and avoid bulk raw chunk storage.
RTConfig = local_config_for_save(RTConfig);
save(Result.ReportMatPath, 'Result', 'RTConfig', 'Source', 'MetadataTable', 'FirstChunkPreview');
writetable(MetadataTable, Result.MetadataCsvPath);

%% ===== SAVE TEXT REPORT =====
% The text report is the MEG-room-facing summary.
fid = fopen(Result.ReportTextPath, 'w');
if fid < 0
    error('Could not open live chunk smoke-test text report: %s', Result.ReportTextPath);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Live chunk smoke test\n');
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
fprintf(fid, 'N requested chunks: %d\n', Result.NRequestedChunks);
fprintf(fid, 'N read chunks: %d\n', Result.NReadChunks);
fprintf(fid, 'N timeouts: %d\n', Result.NTimeouts);
fprintf(fid, 'MaxTimeouts: %d\n', RTConfig.LiveChunkSmokeTest.MaxTimeouts);
fprintf(fid, 'N invalid chunks: %d\n', Result.NInvalidChunks);
fprintf(fid, 'N channels: %s\n', local_text(Result.NChannels));
fprintf(fid, 'First channel label: %s\n', local_first_cell(Result.ChannelNames));
fprintf(fid, 'Last channel label: %s\n', local_last_cell(Result.ChannelNames));
fprintf(fid, 'First sample: %s\n', local_text(Result.FirstSample));
fprintf(fid, 'Last sample: %s\n', local_text(Result.LastSample));
fprintf(fid, 'Sample continuity: %s\n', local_passfail(Result.SampleContinuityPass));
fprintf(fid, 'Internal chunk continuity: %s\n', local_passfail(Result.InternalChunkContinuityPass));
fprintf(fid, 'Cross-chunk continuity: %s\n', local_passfail(Result.CrossChunkContinuityPass));
fprintf(fid, 'Channel count stability: %s\n', local_passfail(Result.ChannelCountStablePass));
fprintf(fid, 'Chunk size: %s\n', local_passfail(Result.ChunkSizePass));
fprintf(fid, 'Timeout: %s\n', local_passfail(Result.TimeoutPass));
fprintf(fid, 'Correction state summary: %s\n', local_struct_summary(Result.CorrectionSummary));
fprintf(fid, 'Final status: %s\n', local_text(Result.Status));
fprintf(fid, 'Final PASS/FAIL: %s\n', local_passfail(Result.Pass));
fprintf(fid, 'StopReason: %s\n', local_text(Result.StopReason));
fprintf(fid, 'Recommendation: %s\n', local_recommendation(Result));
fprintf(fid, 'Messages:\n');
local_print_messages(fid, Result.Messages);

clear cleanupObj

end

function Preview = local_limit_preview(Preview, RTConfig)
% Limit preview dimensions according to config.
maxChannels = RTConfig.LiveChunkSmokeTest.FirstChunkPreviewMaxChannels;
maxSamples = RTConfig.LiveChunkSmokeTest.FirstChunkPreviewMaxSamples;
if isfield(Preview, 'Data') && isnumeric(Preview.Data)
    nChannels = min(size(Preview.Data, 1), maxChannels);
    nSamples = min(size(Preview.Data, 2), maxSamples);
    Preview.Data = Preview.Data(1:nChannels, 1:nSamples);
    if isfield(Preview, 'ChannelNames')
        Preview.ChannelNames = local_cell_subset(Preview.ChannelNames, nChannels);
    end
    if isfield(Preview, 'SampleIndices')
        Preview.SampleIndices = Preview.SampleIndices(1:min(numel(Preview.SampleIndices), nSamples));
    end
end
end

function RTConfig = local_config_for_save(RTConfig)
% Avoid serializing fake-buffer function handles and captured test workspaces.
if isfield(RTConfig, 'Source') && isfield(RTConfig.Source, 'FieldTrip') && ...
        isfield(RTConfig.Source.FieldTrip, 'TestBufferFcn')
    RTConfig.Source.FieldTrip.TestBufferFcn = [];
end
end

function values = local_cell_subset(values, n)
% Return the first n cellstr entries.
values = local_cellstr(values);
values = values(1:min(numel(values), n));
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

function value = local_first_cell(values)
% Return first cell value or empty text.
values = local_cellstr(values);
if isempty(values)
    value = '';
else
    value = values{1};
end
end

function value = local_last_cell(values)
% Return last cell value or empty text.
values = local_cellstr(values);
if isempty(values)
    value = '';
else
    value = values{end};
end
end

function textValue = local_struct_summary(S)
% Build compact summary for correction state.
if ~isstruct(S) || isempty(S)
    textValue = '';
    return;
end
fields = fieldnames(S);
parts = cell(1, numel(fields));
for iField = 1:numel(fields)
    parts{iField} = [fields{iField} '=' local_text(S.(fields{iField}))];
end
textValue = strjoin(parts, '; ');
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

function recommendation = local_recommendation(Result)
% Return a concise next-step recommendation.
if Result.Pass
    recommendation = ...
        'Proceed to Step 3C live RT dry run when in MEG room and after confirming correction order with Marc.';
elseif strcmp(Result.StopReason, 'timeout_limit_exceeded')
    recommendation = ...
        'Check FieldTrip buffer host/port, acquisition status, and wait_dat/get_dat indexing.';
elseif contains(lower(Result.Message), 'sample') || contains(lower(strjoin(local_cellstr(Result.Messages), ' ')), 'gap')
    recommendation = ...
        'Inspect buffer cursor logic and acquisition block behavior before RT dry run.';
elseif contains(lower(Result.Message), 'channel') || contains(lower(strjoin(local_cellstr(Result.Messages), ' ')), 'channel')
    recommendation = ...
        'Do not proceed until live channel labels/count are stable.';
else
    recommendation = 'Resolve smoke-test failures before proceeding to Step 3C.';
end
end
