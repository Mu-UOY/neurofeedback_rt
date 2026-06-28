function test_sync_diagnostics_returned()
% TEST_SYNC_DIAGNOSTICS_RETURNED Ensure sync diagnostics are returned and stored.
%
% USAGE:  test_sync_diagnostics_returned()
%
% DESCRIPTION:
%     Creates a chunk with a sample-index gap and checks both direct sync
%     diagnostics and the diagnostics attached by nf_rt_check_chunk.

%% ===== CONFIGURE SHORT PIPELINE =====
% Filter.Type none avoids toolbox dependencies in this sync-focused test.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Filter.Type = 'none';
RTConfig.ChunkSamples = 2;
RTConfig.PowerWindowSamples = 2;
RTConfig.BufferSamples = 4;
RTConfig.Spatial.NChannels = 1;

RT = nf_rt_init_schema();
RT.SampleCounter.LastSampleIndex = 10;

%% ===== BUILD GAPPED CHUNK =====
% Expected next sample is 11, but chunk starts at 15.
chunk = struct();
chunk.Data = [15 16];
chunk.SampleIndex = 15;
chunk.SampleIndices = 15:16;
chunk.NSamples = 2;
chunk.GapBeforeChunkFlag = false;
chunk.SourceMode = 'simulated_online';
chunk.Timestamp = NaN;

%% ===== CHECK DIRECT SYNC OUTPUT =====
% Sync helper should report the missing samples and update counters.
[chunkOut, RTOut, Diagnostics] = nf_sync_check_dropped_chunks(chunk, RT, RTConfig);

assert(isstruct(Diagnostics), 'Diagnostics was not returned as a struct.');
assert(Diagnostics.DroppedChunkFlag, 'Expected DroppedChunkFlag for a sample-index gap.');
assert(Diagnostics.GapBeforeChunkFlag, 'Expected GapBeforeChunkFlag for a sample-index gap.');
assert(~Diagnostics.DuplicateChunkFlag, 'Did not expect DuplicateChunkFlag.');
assert(Diagnostics.SampleIndexJump == 4, 'Unexpected sample-index jump.');
assert(Diagnostics.MissingSamplesBefore == 4, 'Unexpected missing-sample count.');
assert(chunkOut.DroppedChunkFlag, 'Chunk did not preserve DroppedChunkFlag.');
assert(RTOut.SampleCounter.TotalDroppedSamples == 4, 'RT did not count dropped samples.');

%% ===== CHECK RT CHUNK VALIDATION STORAGE =====
% nf_rt_check_chunk should keep sync diagnostics on the returned chunk.
RT = nf_rt_prepare(RTConfig);
RT.SampleCounter.LastSampleIndex = 10;
[checkedChunk, ~] = nf_rt_check_chunk(chunk, RT, RTConfig);

assert(isfield(checkedChunk, 'SyncDiagnostics'), 'nf_rt_check_chunk did not store SyncDiagnostics.');
assert(checkedChunk.SyncDiagnostics.DroppedChunkFlag, 'Stored SyncDiagnostics did not record the gap.');

end
