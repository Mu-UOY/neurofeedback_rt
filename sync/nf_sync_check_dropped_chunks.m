function [chunk, RT, Diagnostics] = nf_sync_check_dropped_chunks(chunk, RT, RTConfig)
% NF_SYNC_CHECK_DROPPED_CHUNKS Detect sample-index discontinuities.
%
% USAGE:  [chunk, RT, Diagnostics] = nf_sync_check_dropped_chunks(chunk, RT, RTConfig)
%
% DESCRIPTION:
%     Compares each chunk start against the last received sample index,
%     marks dropped or duplicate chunks, updates RT counters, and returns a
%     diagnostics struct for downstream Measure packaging.

%% ===== INITIALIZE CHUNK FLAGS =====
% These fields are always present after sync checking.
chunk.DroppedChunkFlag = false;
chunk.DuplicateChunkFlag = false;
chunk.MissingSamplesBefore = 0;

%% ===== INITIALIZE DIAGNOSTICS =====
% Diagnostics mirrors the chunk flags and records sample-index details.
Diagnostics = struct();
Diagnostics.DroppedChunkFlag = false;
Diagnostics.GapBeforeChunkFlag = false;
Diagnostics.DuplicateChunkFlag = false;
Diagnostics.UnexpectedLengthFlag = false;
Diagnostics.SampleIndexJump = 0;
Diagnostics.MissingSamplesBefore = 0;

%% ===== READ SAMPLE TOLERANCE =====
% Tolerance allows small acceptable sample-index deviations.
tolerance = 0;
if isfield(RTConfig, 'Sync') && isfield(RTConfig.Sync, 'SampleIndexTolerance')
    tolerance = RTConfig.Sync.SampleIndexTolerance;
end

%% ===== CHECK CHUNK LENGTH =====
% Unexpected chunk size is diagnostic; it may still be processable.
if isfield(RTConfig, 'ChunkSamples') && chunk.NSamples ~= RTConfig.ChunkSamples
    Diagnostics.UnexpectedLengthFlag = true;
end

%% ===== CHECK SAMPLE CONTINUITY =====
% Once a previous sample exists, the next chunk should start one sample later.
if isfinite(RT.SampleCounter.LastSampleIndex)
    expectedStart = RT.SampleCounter.LastSampleIndex + 1;
    Diagnostics.SampleIndexJump = chunk.SampleIndex - expectedStart;

    % A later-than-expected start indicates missing samples before this chunk.
    if chunk.SampleIndex > expectedStart + tolerance
        chunk.DroppedChunkFlag = true;
        chunk.GapBeforeChunkFlag = true;
        chunk.MissingSamplesBefore = chunk.SampleIndex - expectedStart;
        Diagnostics.DroppedChunkFlag = true;
        Diagnostics.GapBeforeChunkFlag = true;
        Diagnostics.MissingSamplesBefore = chunk.MissingSamplesBefore;
        RT.Diagnostics.DroppedChunkCount = RT.Diagnostics.DroppedChunkCount + 1;
        RT.SampleCounter.TotalDroppedSamples = RT.SampleCounter.TotalDroppedSamples + chunk.MissingSamplesBefore;

    % An earlier-than-expected start indicates overlap or duplicate data.
    elseif chunk.SampleIndex < expectedStart - tolerance
        chunk.DuplicateChunkFlag = true;
        Diagnostics.DuplicateChunkFlag = true;
        RT.Diagnostics.DuplicatedChunkCount = RT.Diagnostics.DuplicatedChunkCount + 1;
        RT.Diagnostics.LastInvalidReason = 'duplicate_or_overlapping_chunk';
    end
elseif isfield(chunk, 'GapBeforeChunkFlag') && chunk.GapBeforeChunkFlag
    % The first observed chunk can still carry a source-provided gap flag.
    chunk.DroppedChunkFlag = true;
    Diagnostics.DroppedChunkFlag = true;
    Diagnostics.GapBeforeChunkFlag = true;
    RT.Diagnostics.DroppedChunkCount = RT.Diagnostics.DroppedChunkCount + 1;
end

%% ===== CHECK SAMPLE-INDEX VECTOR =====
% SampleIndices must align one-to-one with the data columns.
if chunk.NSamples ~= numel(chunk.SampleIndices)
    Diagnostics.UnexpectedLengthFlag = true;
    RT.Diagnostics.InvalidChunkCount = RT.Diagnostics.InvalidChunkCount + 1;
    RT.Diagnostics.LastInvalidReason = 'sample_indices_length_mismatch';
    error('chunk.SampleIndices length does not match chunk.NSamples.');
end

%% ===== UPDATE SAMPLE COUNTERS =====
% Track the final sample index for the next continuity check.
RT.SampleCounter.LastSampleIndex = chunk.SampleIndex + chunk.NSamples - 1;
RT.SampleCounter.LastChunkNSamples = chunk.NSamples;

end
