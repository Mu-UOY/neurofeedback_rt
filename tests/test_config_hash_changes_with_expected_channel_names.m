function test_config_hash_changes_with_expected_channel_names()
% TEST_CONFIG_HASH_CHANGES_WITH_EXPECTED_CHANNEL_NAMES Check channel-label hash sensitivity.

%% ===== BUILD HASHES =====
RTConfigA = local_hash_config();
RTConfigB = RTConfigA;
RTConfigB.Spatial.ExpectedChannelNames = {'CH001'};

hashA = nf_rt_prepare(RTConfigA).ConfigHash;
hashB = nf_rt_prepare(RTConfigB).ConfigHash;

assert(~strcmp(hashA, hashB), 'Config hash did not change with ExpectedChannelNames.');

end

function RTConfig = local_hash_config()
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Filter.Type = 'none';
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.TargetBand = [8 12];
RTConfig.Fs = 100;
RTConfig.ChunkSamples = 20;
RTConfig.PowerWindowSamples = 40;
RTConfig.BufferSamples = 80;
end
