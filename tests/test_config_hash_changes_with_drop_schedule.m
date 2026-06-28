function test_config_hash_changes_with_drop_schedule()
% TEST_CONFIG_HASH_CHANGES_WITH_DROP_SCHEDULE Check drop schedule hash sensitivity.

%% ===== BUILD HASHES =====
RTConfigA = local_hash_config();
RTConfigB = RTConfigA;
RTConfigB.Simulation.EnableDroppedChunks = true;
RTConfigB.Simulation.DropChunkIndices = [3 5];

hashA = nf_rt_prepare(RTConfigA).ConfigHash;
hashB = nf_rt_prepare(RTConfigB).ConfigHash;

assert(~strcmp(hashA, hashB), 'Config hash did not change with DropChunkIndices.');

%% ===== CHECK RANDOM SEED HASH INPUT =====
% RandomSeed affects probabilistic emitted chunk sequences.
RTConfigC = RTConfigA;
RTConfigD = RTConfigA;
RTConfigC.Simulation.EnableDroppedChunks = true;
RTConfigD.Simulation.EnableDroppedChunks = true;
RTConfigC.Simulation.DropProbability = 0.2;
RTConfigD.Simulation.DropProbability = 0.2;
RTConfigC.Simulation.RandomSeed = 1;
RTConfigD.Simulation.RandomSeed = 2;

hashC = nf_rt_prepare(RTConfigC).ConfigHash;
hashD = nf_rt_prepare(RTConfigD).ConfigHash;

assert(~strcmp(hashC, hashD), 'Config hash did not change with RandomSeed.');

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
