function Buffer = nf_buffer_append(Buffer, Data, sampleIndex, chunk, RTConfig) %#ok<INUSD>
% NF_BUFFER_APPEND Append samples to the circular buffer.
%
% USAGE:  Buffer = nf_buffer_append(Buffer, Data, sampleIndex, chunk, RTConfig)
%
% DESCRIPTION:
%     Writes each sample into the circular buffer, preserving sample indices
%     and gap flags so later power windows can reject discontinuous data.

%% ===== CHECK INPUT DATA =====
% Empty chunks do not change buffer state.
if isempty(Data)
    return;
end

% Buffer rows are post-spatial signals, so incoming data must match.
if size(Data, 1) ~= Buffer.NSignals
    error('Buffer expected %d signals, received %d.', Buffer.NSignals, size(Data, 1));
end

%% ===== DERIVE SAMPLE METADATA =====
% Prefer explicit sample indices from the chunk when the source provides
% them; otherwise assume a contiguous block starting at sampleIndex.
nSamples = size(Data, 2);
if nargin < 4 || isempty(chunk)
    sampleIndices = sampleIndex:(sampleIndex + nSamples - 1);
    gapBeforeChunk = false;
else
    if isfield(chunk, 'SampleIndices') && numel(chunk.SampleIndices) == nSamples
        sampleIndices = chunk.SampleIndices;
    else
        sampleIndices = sampleIndex:(sampleIndex + nSamples - 1);
    end
    gapBeforeChunk = isfield(chunk, 'GapBeforeChunkFlag') && chunk.GapBeforeChunkFlag;
end

%% ===== MARK DISCONTINUITIES =====
% A gap can be internal to the chunk or directly before the first sample.
gapBefore = [false, diff(sampleIndices) ~= 1];
if gapBeforeChunk
    gapBefore(1) = true;
end
isDropped = false(1, nSamples);

%% ===== WRITE CIRCULAR BUFFER =====
% Advance one slot at a time so data and metadata stay aligned.
for iSample = 1:nSamples
    Buffer.WritePointer = mod(Buffer.WritePointer, Buffer.Capacity) + 1;
    Buffer.Data(:, Buffer.WritePointer) = Data(:, iSample);
    Buffer.SampleIndex(Buffer.WritePointer) = sampleIndices(iSample);
    Buffer.GapBeforeSample(Buffer.WritePointer) = gapBefore(iSample);
    Buffer.IsDropped(Buffer.WritePointer) = isDropped(iSample);
    Buffer.TotalWritten = Buffer.TotalWritten + 1;
end

end
