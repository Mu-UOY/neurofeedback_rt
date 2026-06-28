function [chunk, RT] = nf_rt_check_chunk(chunk, RT, RTConfig)
% NF_RT_CHECK_CHUNK Validate one incoming raw MEG chunk.
%
% USAGE:  [chunk, RT] = nf_rt_check_chunk(chunk, RT, RTConfig)
%
% DESCRIPTION:
%     Verifies required chunk fields and dimensions, fills optional metadata
%     defaults, checks spatial compatibility, and attaches synchronization
%     diagnostics for downstream processing.

%% ===== CHECK CHUNK STRUCT =====
% Empty inputs cannot be processed by the real-time path.
if isempty(chunk) || ~isstruct(chunk)
    error('chunk must be a non-empty struct.');
end

%% ===== CHECK REQUIRED FIELDS =====
% Data, SampleIndex, and NSamples define the chunk payload and timing.
required = {'Data','SampleIndex','NSamples'};
for i = 1:numel(required)
    if ~isfield(chunk, required{i})
        error('chunk missing required field: %s', required{i});
    end
end

%% ===== CHECK DATA MATRIX =====
% Raw chunk data is [channels x samples].
if ~isnumeric(chunk.Data) || ndims(chunk.Data) ~= 2
    error('chunk.Data must be a numeric [nChannels x nSamples] matrix.');
end

%% ===== CHECK SAMPLE METADATA =====
% NSamples and SampleIndex must agree with the data matrix and config.
[nChannels, nSamples] = size(chunk.Data);
if nSamples ~= chunk.NSamples
    error('chunk.NSamples (%d) does not match size(chunk.Data,2) (%d).', chunk.NSamples, nSamples);
end
if ~isscalar(chunk.SampleIndex) || ~isfinite(chunk.SampleIndex) || chunk.SampleIndex ~= round(chunk.SampleIndex)
    error('chunk.SampleIndex must be a finite integer scalar.');
end
if chunk.NSamples <= 0
    error('chunk.NSamples must be positive.');
end
if chunk.NSamples > RTConfig.ChunkSamples
    error('chunk.NSamples (%d) exceeds RTConfig.ChunkSamples (%d).', chunk.NSamples, RTConfig.ChunkSamples);
end

%% ===== FILL OPTIONAL CHUNK FIELDS =====
% Defaults keep downstream code from checking every optional field.
if ~isfield(chunk, 'SampleIndices') || numel(chunk.SampleIndices) ~= chunk.NSamples
    chunk.SampleIndices = chunk.SampleIndex:(chunk.SampleIndex + chunk.NSamples - 1);
end
if ~isfield(chunk, 'SourceMode')
    chunk.SourceMode = RTConfig.Source.Mode;
end
if ~isfield(chunk, 'Timestamp')
    chunk.Timestamp = NaN;
end
if ~isfield(chunk, 'GapBeforeChunkFlag')
    chunk.GapBeforeChunkFlag = false;
end
if ~isfield(chunk, 'SimulatedDropFlag')
    chunk.SimulatedDropFlag = false;
end

%% ===== CHECK SPATIAL COMPATIBILITY =====
% Spatial projection columns must match raw channel count before projection.
if size(RT.Spatial.CombinedMatrix, 2) ~= nChannels
    error('Spatial matrix expects %d channels, chunk has %d.', size(RT.Spatial.CombinedMatrix, 2), nChannels);
end

%% ===== CHECK SAMPLE SYNCHRONY =====
% Sync diagnostics are stored on the chunk for later Measure packaging.
[chunk, RT, SyncDiagnostics] = nf_sync_check_dropped_chunks(chunk, RT, RTConfig);
chunk.SyncDiagnostics = SyncDiagnostics;

end
