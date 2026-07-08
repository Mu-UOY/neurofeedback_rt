function test_live_source_dispatch_preserves_simulated_modes()
% TEST_LIVE_SOURCE_DISPATCH_PRESERVES_SIMULATED_MODES Check existing source path.

%% ===== SIMULATED SOURCE STILL READS CHUNKS =====
RTConfig = nf_default_config();
RTConfig.ChunkSamples = 5;
RTConfig.PowerWindowSamples = 10;
RTConfig.BufferSamples = 10;
RTConfig.Source.StartSample = 1;
RTConfig.Source.EndSample = 12;

Data.X = reshape(1:40, 2, 20);
Data.Fs = RTConfig.Fs;
Data.ChannelNames = {'CH001','CH002'};

Source = nf_source_init('simulated_online', Data, RTConfig);
[chunk, Source] = nf_get_meg_chunk(Source, RTConfig);

assert(chunk.SampleIndex == 1, 'Simulated chunk start changed.');
assert(chunk.NSamples == 5, 'Simulated chunk size changed.');
assert(Source.CurrentSample == 6, 'Simulated source cursor changed incorrectly.');

end
