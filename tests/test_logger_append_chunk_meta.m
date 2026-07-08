function test_logger_append_chunk_meta()
% TEST_LOGGER_APPEND_CHUNK_META Check chunk metadata normalization.

%% ===== INITIALIZE LOGGER =====
% Chunk append must strip raw Data and tolerate missing optional fields.
[RTConfig, cleanupObj] = local_temp_config(); %#ok<ASGLU>
Logger = nf_logger_init(RTConfig, 'mock_live_test', struct());

chunk = struct();
chunk.Data = randn(2, 480);
chunk.SampleIndex = 1001;
chunk.SampleIndices = 1001:1480;
chunk.NSamples = 480;
chunk.ChannelNames = {'C1','C2'};
chunk.SourceMode = RTConfig.Source.Mode;
chunk.GapBeforeChunkFlag = false;

Logger = nf_logger_append_chunk_meta(Logger, chunk);

assert(Logger.NChunks == 1, 'Chunk count did not increment.');
assert(numel(Logger.ChunkMeta) == 1, 'ChunkMeta row count mismatch.');
assert(Logger.ChunkMeta(1).StartSample == 1001, 'StartSample mismatch.');
assert(Logger.ChunkMeta(1).StopSample == 1480, 'StopSample mismatch.');
assert(Logger.ChunkMeta(1).NSamples == 480, 'NSamples mismatch.');
assert(Logger.ChunkMeta(1).NChannels == 2, 'NChannels mismatch.');
assert(~isfield(Logger.ChunkMeta(1), 'Data'), 'Raw Data was stored in ChunkMeta.');

minimalChunk = struct();
minimalChunk.SampleIndex = 2001;
Logger = nf_logger_append_chunk_meta(Logger, minimalChunk);
assert(Logger.NChunks == 2, 'Minimal chunk was not appended.');
assert(numel(Logger.ChunkMeta) == 2, 'Heterogeneous chunk inputs did not normalize.');
assert(Logger.ChunkMeta(2).ChunkIndex == 2, 'Default ChunkIndex was wrong.');

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
