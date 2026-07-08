function test_save_partial_log_is_incremental()
% TEST_SAVE_PARTIAL_LOG_IS_INCREMENTAL Check delta-based checkpoint saves.

%% ===== SAVE TWO PARTIAL LOGS =====
% The second partial should contain only records appended since the first.
[RTConfig, cleanupObj] = local_temp_config(); %#ok<ASGLU>
Logger = nf_logger_init(RTConfig, 'mock_live_test', struct());

Logger = nf_logger_append_chunk_meta(Logger, local_chunk(RTConfig, 1));
Logger = nf_logger_append_measure(Logger, nf_measure_empty());
Logger = nf_save_partial_log(Logger, 'mock_live_test', 'first');
partialAPath = Logger.LastPartialSavePath;

Logger = nf_logger_append_chunk_meta(Logger, local_chunk(RTConfig, 2));
Measure2 = nf_measure_empty();
Measure2.Power = 2;
Logger = nf_logger_append_measure(Logger, Measure2);
Logger = nf_save_partial_log(Logger, 'mock_live_test', 'second');
partialBPath = Logger.LastPartialSavePath;

loadedA = load(partialAPath);
loadedB = load(partialBPath);
PartialLogA = loadedA.PartialLog;
PartialLogB = loadedB.PartialLog;

assert(PartialLogA.FirstChunkIndex == 1 && PartialLogA.LastChunkIndex == 1, ...
    'First partial chunk indices are wrong.');
assert(numel(PartialLogA.ChunkMetaDelta) == 1, ...
    'First partial should contain one chunk delta.');
assert(PartialLogA.FirstMeasureIndex == 1 && PartialLogA.LastMeasureIndex == 1, ...
    'First partial Measure indices are wrong.');
assert(numel(PartialLogA.MeasuresDelta) == 1, ...
    'First partial should contain one Measure delta.');

assert(PartialLogB.FirstChunkIndex == 2 && PartialLogB.LastChunkIndex == 2, ...
    'Second partial chunk indices are wrong.');
assert(numel(PartialLogB.ChunkMetaDelta) == 1, ...
    'Second partial should contain one chunk delta.');
assert(PartialLogB.FirstMeasureIndex == 2 && PartialLogB.LastMeasureIndex == 2, ...
    'Second partial Measure indices are wrong.');
assert(numel(PartialLogB.MeasuresDelta) == 1, ...
    'Second partial should contain one Measure delta.');
assert(~isfield(PartialLogB, 'Logger'), 'PartialLogB must not contain full Logger.');

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
