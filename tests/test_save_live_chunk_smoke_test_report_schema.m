function test_save_live_chunk_smoke_test_report_schema()
% TEST_SAVE_LIVE_CHUNK_SMOKE_TEST_REPORT_SCHEMA Check saved files and columns.

%% ===== BUILD MINIMAL RESULT =====
RTConfig = nf_live_config();
tempProjectRoot = tempname;
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() rmdir(tempProjectRoot, 's')); %#ok<NASGU>
RTConfig.Paths.ProjectRoot = tempProjectRoot;
RTConfig.LiveChunkSmokeTest.NChunks = 1;
RTConfig.Debug.Verbose = false;

Result = local_minimal_result();
Source.Mode = RTConfig.Source.Mode;
Source.LiveAdapter = RTConfig.Source.LiveAdapter;
Source.ResolvedConnection.Host = '';
Source.ResolvedConnection.Port = [];
Source.ResolvedConnection.UsedTestHook = true;

FirstChunkPreview.Data = ones(2, 10);
FirstChunkPreview.ChannelNames = {'MEG001','MEG002'};
FirstChunkPreview.SampleIndices = 1:10;

Result = nf_save_live_chunk_smoke_test(Result, RTConfig, Source, FirstChunkPreview);

assert(exist(Result.ReportMatPath, 'file') == 2, 'MAT report missing.');
assert(exist(Result.ReportTextPath, 'file') == 2, 'TXT report missing.');
assert(exist(Result.MetadataCsvPath, 'file') == 2, 'CSV report missing.');
assert(~isempty(Result.ReportMatPath), 'Result.ReportMatPath is empty.');
assert(~isempty(Result.ReportTextPath), 'Result.ReportTextPath is empty.');
assert(~isempty(Result.MetadataCsvPath), 'Result.MetadataCsvPath is empty.');

T = readtable(Result.MetadataCsvPath);
expectedColumns = {'RunID','ChunkIndex','TimeoutFlag','InvalidChunkFlag', ...
    'InvalidReason','StartSample','StopSample','NSamples','ExpectedNSamples', ...
    'NChannels','ExpectedNChannels','FirstSample','LastSample', ...
    'InternalContinuityPass','CrossChunkContinuityPass','ReadHeaderNSamples', ...
    'SourceMode','HasCorrectionInfo','AppliedChannelGains', ...
    'AppliedMegRefCorrection','RemovedBlockMean','AppliedProjector', ...
    'RequiresMarcConfirmation','MarcConfirmed','ReadStartTime','ReadEndTime', ...
    'ReadRuntimeSecs'};
assert(isempty(setdiff(expectedColumns, T.Properties.VariableNames)), ...
    'Metadata CSV missing expected columns.');

end

function Result = local_minimal_result()
% Build a minimal saveable smoke-test Result.
Result.Type = 'live_chunk_smoke_test';
Result.Pass = true;
Result.Status = 'PASS';
Result.Message = 'Live chunk smoke test passed.';
Result.StopReason = '';
Result.RunID = 'unit_test';
Result.SessionDir = '';
Result.ReportMatPath = '';
Result.ReportTextPath = '';
Result.MetadataCsvPath = '';
Result.FirstChunkPreviewPath = '';
Result.NRequestedChunks = 1;
Result.NReadChunks = 1;
Result.NTimeouts = 0;
Result.NInvalidChunks = 0;
Result.Fs = 2400;
Result.ExpectedFs = 2400;
Result.ChunkSamples = 480;
Result.ExpectedChunkSamples = 480;
Result.NChannels = 2;
Result.ChannelNames = {'MEG001','MEG002'};
Result.FirstSample = 1;
Result.LastSample = 480;
Result.SampleContinuityPass = true;
Result.InternalChunkContinuityPass = true;
Result.CrossChunkContinuityPass = true;
Result.ChannelCountStablePass = true;
Result.ChunkSizePass = true;
Result.TimeoutPass = true;
Result.CorrectionSummary = struct();
Result.Messages = {};
Result.MetadataTable = table({'unit_test'}, 1, false, false, {''}, 1, 480, ...
    480, 480, 2, 2, 1, 480, true, true, 480, {'live_fieldtrip'}, ...
    true, false, false, true, false, true, false, {'start'}, {'end'}, 0.01, ...
    'VariableNames', {'RunID','ChunkIndex','TimeoutFlag','InvalidChunkFlag', ...
    'InvalidReason','StartSample','StopSample','NSamples','ExpectedNSamples', ...
    'NChannels','ExpectedNChannels','FirstSample','LastSample', ...
    'InternalContinuityPass','CrossChunkContinuityPass','ReadHeaderNSamples', ...
    'SourceMode','HasCorrectionInfo','AppliedChannelGains', ...
    'AppliedMegRefCorrection','RemovedBlockMean','AppliedProjector', ...
    'RequiresMarcConfirmation','MarcConfirmed','ReadStartTime','ReadEndTime', ...
    'ReadRuntimeSecs'});
end
