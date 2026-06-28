function Buffer = nf_buffer_init(NSignals, RTConfig)
% NF_BUFFER_INIT Initialize a fixed-length circular sample buffer.
%
% USAGE:  Buffer = nf_buffer_init(NSignals, RTConfig)
%
% DESCRIPTION:
%     Creates the fixed-size storage used by real-time processing to hold the
%     most recent post-spatial, post-filter samples and their sync metadata.

%% ===== CHECK SIGNAL COUNT =====
% The buffer stores one row per projected signal.
if ~isscalar(NSignals) || NSignals <= 0 || NSignals ~= round(NSignals)
    error('NSignals must be a positive integer scalar.');
end

%% ===== CHECK BUFFER CAPACITY =====
% Capacity must be a positive integer number of samples.
capacity = RTConfig.BufferSamples;
if ~isscalar(capacity) || capacity <= 0 || capacity ~= round(capacity)
    error('RTConfig.BufferSamples must be a positive integer scalar.');
end

%% ===== INITIALIZE BUFFER STATE =====
% NaN sample indices/data make unwritten slots obvious during debugging.
Buffer = struct();
Buffer.Data = NaN(NSignals, capacity);
Buffer.SampleIndex = NaN(1, capacity);
Buffer.GapBeforeSample = false(1, capacity);
Buffer.IsDropped = false(1, capacity);
Buffer.Capacity = capacity;
Buffer.NSignals = NSignals;
Buffer.WritePointer = 0;
Buffer.TotalWritten = 0;

end
