function window = nf_buffer_getlast(Buffer, N)
% NF_BUFFER_GETLAST Return the last N samples in chronological order.
%
% USAGE:  window = nf_buffer_getlast(Buffer, N)
%
% DESCRIPTION:
%     Extracts a chronological view from the circular buffer without exposing
%     unwritten slots, even before the buffer has reached capacity.

%% ===== PARSE WINDOW LENGTH =====
% Default to the full available buffer capacity.
if nargin < 2 || isempty(N)
    N = Buffer.Capacity;
end

%% ===== COMPUTE AVAILABLE SAMPLES =====
% TotalWritten can exceed Capacity after wraparound.
filled = min(Buffer.TotalWritten, Buffer.Capacity);
NActual = min(N, filled);

%% ===== HANDLE EMPTY BUFFER =====
% Return the same window schema with empty payloads.
window = struct();
if NActual == 0
    window.Data = [];
    window.SampleIndex = [];
    window.GapBeforeSample = [];
    window.IsDropped = [];
    window.NSamples = 0;
    window.ContainsDropped = false;
    return;
end

%% ===== BUILD READ INDICES =====
% Before wraparound, the latest samples are contiguous in memory.
if Buffer.TotalWritten < Buffer.Capacity
    startIdx = Buffer.WritePointer - NActual + 1;
    stopIdx = Buffer.WritePointer;
    readIdx = startIdx:stopIdx;
else
    % After wraparound, modulo arithmetic restores chronological order.
    last = Buffer.WritePointer;
    readIdx = (last - NActual + 1):last;
    readIdx = mod(readIdx - 1, Buffer.Capacity) + 1;
end

%% ===== PACKAGE WINDOW =====
% Preserve data and all gap/drop metadata for downstream validation.
window.Data = Buffer.Data(:, readIdx);
window.SampleIndex = Buffer.SampleIndex(readIdx);
window.GapBeforeSample = Buffer.GapBeforeSample(readIdx);
window.IsDropped = Buffer.IsDropped(readIdx);
window.NSamples = NActual;
window.ContainsDropped = any(window.IsDropped);

end
