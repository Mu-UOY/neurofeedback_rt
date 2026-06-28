function test_buffer_gap_detection()
% TEST_BUFFER_GAP_DETECTION Ensure sample-index discontinuities invalidate windows.
%
% USAGE:  test_buffer_gap_detection()
%
% DESCRIPTION:
%     Appends two chunks with a missing sample between them and confirms the
%     returned buffer window is marked as gapped.

%% ===== SET UP BUFFER =====
% Small capacity keeps the test focused on the appended samples.
RTConfig = nf_default_config();
RTConfig.BufferSamples = 10;

Buffer = nf_buffer_init(1, RTConfig);

%% ===== APPEND CONTIGUOUS FIRST CHUNK =====
% The first chunk starts with no gap.
chunk1 = struct();
chunk1.SampleIndices = 1:3;
chunk1.GapBeforeChunkFlag = false;
chunk1.DroppedChunkFlag = false;
Buffer = nf_buffer_append(Buffer, 1:3, 1, chunk1, RTConfig);

%% ===== APPEND GAPPED SECOND CHUNK =====
% Sample 4 is missing, so the second chunk carries a gap flag.
chunk2 = struct();
chunk2.SampleIndices = 5:6;
chunk2.GapBeforeChunkFlag = true;
chunk2.DroppedChunkFlag = true;
Buffer = nf_buffer_append(Buffer, 5:6, 5, chunk2, RTConfig);

%% ===== CHECK GAP DETECTION =====
% The combined window should be rejected as discontinuous.
window = nf_buffer_getlast(Buffer, 5);
assert(nf_buffer_window_has_gap(window), 'Expected a gap in sample indices.');

end
