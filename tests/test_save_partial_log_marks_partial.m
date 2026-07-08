function test_save_partial_log_marks_partial()
% TEST_SAVE_PARTIAL_LOG_MARKS_PARTIAL Check checkpoint metadata.

%% ===== SAVE PARTIAL LOG =====
% Partial logs must not look like finalized baseline/trial outputs.
[Logger, cleanupObj] = local_logger_with_one_record(); %#ok<ASGLU>

Logger = nf_save_partial_log(Logger, 'live_trial', 'unit_test_crash');

assert(exist(Logger.LastPartialSavePath, 'file') == 2, ...
    'Partial log file was not created.');
assert(Logger.Closed == false, 'Partial save closed the logger.');
assert(Logger.Partial == true, 'Logger should remain partial after checkpoint.');
assert(Logger.Finalized == false, 'Logger should not be finalized after checkpoint.');
assert(Logger.LastPartialSavedChunkIndex == Logger.NChunks, ...
    'Partial chunk save index was not updated.');
assert(Logger.LastPartialSavedMeasureIndex == Logger.NMeasures, ...
    'Partial Measure save index was not updated.');

loaded = load(Logger.LastPartialSavePath);
assert(isfield(loaded, 'PartialLog'), 'Partial MAT missing PartialLog variable.');
assert(~isfield(loaded, 'Baseline'), 'Partial MAT must not contain Baseline.');
PartialLog = loaded.PartialLog;
assert(strcmp(PartialLog.Type, 'partial_log'), 'PartialLog.Type mismatch.');
assert(PartialLog.Partial == true, 'PartialLog.Partial should be true.');
assert(PartialLog.Finalized == false, 'PartialLog.Finalized should be false.');
assert(strcmp(PartialLog.Reason, 'unit_test_crash'), 'PartialLog reason mismatch.');
assert(isfield(PartialLog, 'ChunkMetaDelta'), 'PartialLog missing ChunkMetaDelta.');
assert(isfield(PartialLog, 'MeasuresDelta'), 'PartialLog missing MeasuresDelta.');
assert(~isfield(PartialLog, 'Logger'), 'PartialLog must not contain full Logger.');

end

function [Logger, cleanupObj] = local_logger_with_one_record()
[RTConfig, cleanupObj] = local_temp_config();
Logger = nf_logger_init(RTConfig, 'mock_live_test', struct());
Logger = nf_logger_append_chunk_meta(Logger, local_chunk(RTConfig, 1));
Logger = nf_logger_append_measure(Logger, nf_measure_empty());
end

function chunk = local_chunk(RTConfig, idx)
startSample = 1 + (idx - 1) * RTConfig.ChunkSamples;
stopSample = startSample + RTConfig.ChunkSamples - 1;
chunk = struct();
chunk.SampleIndex = startSample;
chunk.SampleIndices = startSample:stopSample;
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
