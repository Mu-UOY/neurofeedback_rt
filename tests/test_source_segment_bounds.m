function test_source_segment_bounds()
% TEST_SOURCE_SEGMENT_BOUNDS Simulated sources must respect configured bounds.
%
% USAGE:  test_source_segment_bounds()
%
% DESCRIPTION:
%     Initializes a simulated source with configured start/end samples and
%     confirms chunk reads stay within those bounds.

%% ===== CONFIGURE SOURCE BOUNDS =====
% Chunk size four should split samples 5:12 into two chunks.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.ChunkSamples = 4;
RTConfig.Source.StartSample = 5;
RTConfig.Source.EndSample = 12;

%% ===== BUILD DATASET =====
% One-channel data makes sample values equal sample indices.
Data = struct();
Data.X = 1:20;
Data.Fs = RTConfig.Fs;
Data.ChannelNames = {'CH001'};

Source = nf_source_init('simulated_resting', Data, RTConfig);

%% ===== CHECK INITIAL SOURCE STATE =====
% Source cursor should start at configured StartSample.
assert(Source.StartSample == 5, 'Source.StartSample did not respect RTConfig.');
assert(Source.EndSample == 12, 'Source.EndSample did not respect RTConfig.');
assert(Source.CurrentSample == 5, 'Source.CurrentSample did not start at Source.StartSample.');

%% ===== CHECK FIRST CHUNK =====
% First chunk should cover samples 5:8.
[chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
assert(chunk.SampleIndex == 5, 'First chunk did not start at configured StartSample.');
assert(isequal(chunk.SampleIndices, 5:8), 'Unexpected first chunk sample indices.');
assert(isequal(chunk.Data, 5:8), 'Unexpected first chunk data.');

%% ===== CHECK FINAL CHUNK =====
% Second chunk should stop exactly at EndSample.
[chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
assert(isequal(chunk.SampleIndices, 9:12), 'Unexpected second chunk sample indices.');
assert(~nf_source_has_next(Source), 'Source should be exhausted at configured EndSample.');

end
