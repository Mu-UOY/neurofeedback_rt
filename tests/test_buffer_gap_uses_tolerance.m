function test_buffer_gap_uses_tolerance()
% TEST_BUFFER_GAP_USES_TOLERANCE Buffer gap checks must honor sync tolerance.
%
% USAGE:  test_buffer_gap_uses_tolerance()
%
% DESCRIPTION:
%     Builds a window with a one-sample index jump and verifies that gap
%     detection depends on RTConfig.Sync.SampleIndexTolerance.

%% ===== SET UP TOLERANT CONFIG =====
% A tolerance of one sample should accept the [1 2 4] index sequence.
RTConfig = nf_default_config();
RTConfig.BufferSamples = 5;
RTConfig.Sync.SampleIndexTolerance = 1;

Buffer = nf_buffer_init(1, RTConfig);

%% ===== APPEND WINDOW WITH SMALL JUMP =====
% The chunk has a sample-index jump but no explicit source gap flag.
chunk = struct();
chunk.SampleIndices = [1 2 4];
chunk.GapBeforeChunkFlag = false;
chunk.DroppedChunkFlag = false;

Buffer = nf_buffer_append(Buffer, [10 20 40], 1, chunk, RTConfig);
window = nf_buffer_getlast(Buffer, 3);

%% ===== CHECK TOLERANT CASE =====
% Positive tolerance accepts the one-sample jump.
assert(~nf_buffer_window_has_gap(window, RTConfig), 'Gap check ignored positive sample-index tolerance.');

%% ===== CHECK STRICT CASE =====
% Zero tolerance rejects the same window.
RTConfig.Sync.SampleIndexTolerance = 0;
assert(nf_buffer_window_has_gap(window, RTConfig), 'Gap check did not detect gap with zero tolerance.');

end
