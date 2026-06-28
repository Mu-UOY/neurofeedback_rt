function test_buffer_wraparound()
% TEST_BUFFER_WRAPAROUND Ensure circular buffer returns chronological wrapped data.
%
% USAGE:  test_buffer_wraparound()
%
% DESCRIPTION:
%     Writes more samples than the buffer capacity and confirms getlast
%     returns the most recent samples in chronological order.

%% ===== SET UP SMALL BUFFER =====
% Capacity five forces wraparound after seven appended samples.
RTConfig = nf_default_config();
RTConfig.BufferSamples = 5;

Buffer = nf_buffer_init(1, RTConfig);
chunk = struct();
chunk.SampleIndices = 1:7;
chunk.GapBeforeChunkFlag = false;
chunk.DroppedChunkFlag = false;

%% ===== APPEND THROUGH WRAPAROUND =====
% The circular buffer should retain samples 3 through 7.
Buffer = nf_buffer_append(Buffer, 1:7, 1, chunk, RTConfig);
window = nf_buffer_getlast(Buffer, 5);

%% ===== CHECK CHRONOLOGICAL OUTPUT =====
% Wrapped storage must still read out in sample order.
assert(window.NSamples == 5, 'Expected 5 samples.');
assert(isequal(window.SampleIndex, 3:7), 'Wrapped sample indices are not chronological.');
assert(isequal(window.Data, 3:7), 'Wrapped data are not chronological.');

end
