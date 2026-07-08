function test_save_live_rt_dry_run_report_schema()
% TEST_SAVE_LIVE_RT_DRY_RUN_REPORT_SCHEMA Check save helper outputs.

[RTConfig, tempRoot] = nf_test_live_rt_dry_run_config(35);
cleanupObj = onCleanup(@() local_cleanup(tempRoot));

Result = local_result();
Source = local_source();
RT = local_rt();
Measures = nf_measure_empty();
Measures.IsValid = true;
Measures.Power = 1;
Measures.SourceMode = RTConfig.Source.Mode;
Measures.Band = RTConfig.TargetBand;
Result.MetadataTable = struct2table(local_metadata_row(Result.RunID), 'AsArray', true);
Result.MeasureTable = nf_measures_to_table(Measures, RTConfig);

Result = nf_save_live_rt_dry_run(Result, RTConfig, Source, RT, Measures);

assert(exist(Result.ReportMatPath, 'file') == 2, 'MAT report missing.');
assert(exist(Result.ReportTextPath, 'file') == 2, 'TXT report missing.');
assert(exist(Result.MeasureCsvPath, 'file') == 2, 'Measure CSV missing.');
assert(exist(Result.ChunkMetaCsvPath, 'file') == 2, 'Chunk metadata CSV missing.');
assert(~isempty(Result.ReportMatPath), 'ReportMatPath was empty.');
assert(~isempty(Result.ReportTextPath), 'ReportTextPath was empty.');
assert(~isempty(Result.MeasureCsvPath), 'MeasureCsvPath was empty.');
assert(~isempty(Result.ChunkMetaCsvPath), 'ChunkMetaCsvPath was empty.');

MeasureTable = readtable(Result.MeasureCsvPath);
ChunkTable = readtable(Result.ChunkMetaCsvPath);
assert(ismember('Power', MeasureTable.Properties.VariableNames), 'Measure CSV missing Power.');
assert(ismember('RunID', ChunkTable.Properties.VariableNames), 'Chunk CSV missing RunID.');
assert(ismember('ProcessingRuntimeSecs', ChunkTable.Properties.VariableNames), ...
    'Chunk CSV missing ProcessingRuntimeSecs.');

clear cleanupObj
end

function Result = local_result()
Result = struct();
Result.Type = 'live_rt_dry_run';
Result.Pass = true;
Result.Status = 'PASS';
Result.Message = 'schema test';
Result.StopReason = '';
Result.ErrorMessage = '';
Result.RunID = 'schema_test';
Result.SessionDir = '';
Result.ReportMatPath = '';
Result.ReportTextPath = '';
Result.MeasureCsvPath = '';
Result.ChunkMetaCsvPath = '';
Result.NRequestedChunks = 1;
Result.NReadChunks = 1;
Result.NProcessedChunks = 1;
Result.NTimeouts = 0;
Result.NInvalidChunks = 0;
Result.NMeasures = 1;
Result.NValidMeasures = 1;
Result.FirstValidMeasureChunk = 1;
Result.Fs = 2400;
Result.ExpectedFs = 2400;
Result.ChunkSamples = 480;
Result.ExpectedChunkSamples = 480;
Result.PowerWindowSamples = 4800;
Result.ExpectedPowerWindowSamples = 4800;
Result.NChannels = 3;
Result.NSignals = 1;
Result.ChannelNames = {'MEG001','MEG002','MEG003'};
Result.OutputSignalNames = {'technical_fallback_signal'};
Result.Spatial = struct('MatrixSource', 'technical_fallback', ...
    'IsTechnicalFallback', true);
Result.RTHasBaseline = false;
Result.RTPrepared = true;
Result.FilterStateUpdatedPass = true;
Result.BufferFilledPass = true;
Result.ValidMeasureAppearedPass = true;
Result.PowerWindowLengthPass = true;
Result.FeedbackUnmappedPass = true;
Result.NoBaselinePass = true;
Result.TimingPass = true;
Result.MeanProcessingSeconds = 0.01;
Result.MaxProcessingSeconds = 0.02;
Result.MetadataTable = table();
Result.MeasureTable = table();
Result.RTSummary = struct();
Result.Messages = {};
end

function Source = local_source()
Source = struct();
Source.Mode = 'live_fieldtrip';
Source.LiveAdapter = 'ben_fieldtrip_buffer';
Source.ResolvedConnection = struct('Host', 'test', 'Port', 2101, ...
    'UsedTestHook', true);
end

function RT = local_rt()
RT = struct();
RT.HasBaseline = false;
RT.PreparedAt = '2026-01-01 00:00:00';
end

function row = local_metadata_row(runID)
row = struct();
row.RunID = runID;
row.ChunkIndex = 1;
row.TimeoutFlag = false;
row.InvalidChunkFlag = false;
row.InvalidReason = '';
row.StartSample = 1;
row.StopSample = 480;
row.NSamples = 480;
row.ExpectedNSamples = 480;
row.NChannels = 3;
row.NSignals = 1;
row.ReadHeaderNSamples = 480;
row.SourceMode = 'live_fieldtrip';
row.MeasureIsValid = true;
row.MeasureInvalidReason = '';
row.MeasurePower = 1;
row.MeasureZRaw = NaN;
row.MeasureZClipped = NaN;
row.MeasureZSmoothed = NaN;
row.MeasureFeedbackValue = NaN;
row.WindowStartSample = 1;
row.WindowEndSample = 4800;
row.WindowLengthSamples = 4800;
row.PowerWindowLengthPass = true;
row.ReadStartTime = '';
row.ReadEndTime = '';
row.ProcessingStartTime = '';
row.ProcessingEndTime = '';
row.ReadRuntimeSecs = 0.01;
row.ProcessingRuntimeSecs = 0.01;
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
