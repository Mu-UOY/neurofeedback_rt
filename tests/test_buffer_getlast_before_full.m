function test_buffer_getlast_before_full()
% TEST_BUFFER_GETLAST_BEFORE_FULL Ensure getlast avoids unwritten slots.
%
% USAGE:  test_buffer_getlast_before_full()
%
% DESCRIPTION:
%     Appends fewer samples than requested from nf_buffer_getlast and checks
%     that only written samples are returned.

%% ===== SET UP PARTIAL BUFFER =====
% Capacity is larger than the number of written samples.
RTConfig = nf_default_config();
RTConfig.BufferSamples = 10;

Buffer = nf_buffer_init(1, RTConfig);
chunk = struct();
chunk.SampleIndices = 1:3;
chunk.GapBeforeChunkFlag = false;
chunk.DroppedChunkFlag = false;

%% ===== READ MORE THAN WRITTEN =====
% Requesting five samples should return the three available samples.
Buffer = nf_buffer_append(Buffer, 1:3, 1, chunk, RTConfig);
window = nf_buffer_getlast(Buffer, 5);

%% ===== CHECK WINDOW CONTENTS =====
% Unwritten NaN slots must not appear in the returned window.
assert(window.NSamples == 3, 'Expected only the three written samples.');
assert(isequal(window.SampleIndex, 1:3), 'Unexpected sample indices before buffer is full.');
assert(isequal(window.Data, 1:3), 'Unexpected data before buffer is full.');
assert(all(isfinite(window.Data(:))), 'Window includes unwritten NaN slots.');

end
