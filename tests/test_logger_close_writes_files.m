function test_logger_close_writes_files()
% TEST_LOGGER_CLOSE_WRITES_FILES Check final logger outputs.

%% ===== CLOSE LOGGER =====
% Close should write final MAT and CSV audit files.
[RTConfig, cleanupObj] = local_temp_config(); %#ok<ASGLU>
Logger = nf_logger_init(RTConfig, 'mock_live_test', struct());
Logger = nf_logger_append_chunk_meta(Logger, local_chunk(RTConfig));
Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.Power = 1.23;
Logger = nf_logger_append_measure(Logger, Measure);

Logger = nf_logger_close(Logger);

assert(Logger.Closed == true, 'Logger did not close.');
assert(Logger.Partial == false, 'Closed Logger should not be partial.');
assert(Logger.Finalized == true, 'Closed Logger should be finalized.');
assert(exist(Logger.FinalLogPath, 'file') == 2, 'Final log MAT missing.');
assert(exist(Logger.MeasureTablePath, 'file') == 2, 'Measure CSV missing.');
assert(exist(Logger.ChunkMetaPath, 'file') == 2, 'Chunk CSV missing.');
assert(exist(Logger.SessionSummaryPath, 'file') == 2, 'Session summary missing.');

loaded = load(Logger.FinalLogPath);
assert(isfield(loaded, 'FinalLog'), 'Final MAT missing FinalLog variable.');
FinalLog = loaded.FinalLog;
assert(strcmp(FinalLog.Type, 'logger_final_log'), 'FinalLog.Type mismatch.');
assert(FinalLog.Partial == false, 'FinalLog.Partial should be false.');
assert(FinalLog.Finalized == true, 'FinalLog.Finalized should be true.');
assert(isfield(FinalLog, 'Logger'), 'FinalLog missing complete Logger.');

end

function chunk = local_chunk(RTConfig)
chunk = struct();
chunk.SampleIndex = 1001;
chunk.SampleIndices = 1001:(1000 + RTConfig.ChunkSamples);
chunk.NSamples = RTConfig.ChunkSamples;
chunk.ChannelNames = {'C1','C2'};
chunk.SourceMode = RTConfig.Source.Mode;
end

function [RTConfig, cleanupObj] = local_temp_config()
tempProjectRoot = tempname();
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() local_rmdir(tempProjectRoot));
RTConfig = nf_mock_live_test_config();
RTConfig.Debug.Verbose = false;
RTConfig.Paths.ProjectRoot = tempProjectRoot;
end

function local_rmdir(pathToRemove)
if exist(pathToRemove, 'dir')
    rmdir(pathToRemove, 's');
end
end
