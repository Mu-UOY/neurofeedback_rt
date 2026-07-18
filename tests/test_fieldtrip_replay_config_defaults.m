function test_fieldtrip_replay_config_defaults()
% TEST_FIELDTRIP_REPLAY_CONFIG_DEFAULTS Check local replay endpoint defaults.

%% ===== BUILD CONFIG =====
Modes = nf_modes();
datasetPath = [tempname, '.mat'];
save(datasetPath, 'datasetPath');
cleanupObj = onCleanup(@() local_cleanup(datasetPath));

RTIn = nf_live_config();
RTIn.TargetBand = [8 12];
RTIn.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTIn.Source.CTF.ApplyChannelGains = true;

[RTConfig, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath, RTIn);

assert(strcmp(RTConfig.Source.Mode, Modes.Source.LiveFieldTrip), 'Source mode changed.');
assert(strcmp(RTConfig.Source.LiveAdapter, Modes.LiveAdapter.BenFieldTrip), 'Live adapter changed.');
assert(strcmp(RTConfig.Source.FieldTrip.Host, 'localhost'), 'Unexpected local replay host.');
assert(RTConfig.Source.FieldTrip.Port == 1900 + 72, 'Unexpected local replay port.');
assert(strcmp(RTConfig.Source.FieldTrip.StreamRole, Modes.StreamRole.LocalReplay), ...
    'StreamRole was not marked local_replay.');
assert(ReplayConfig.Speed == 1, 'Default replay speed mismatch.');
assert(ReplayConfig.BlockSeconds == RTIn.ChunkSeconds, 'BlockSeconds did not follow ChunkSeconds.');
assert(ReplayConfig.ReadEvents == true, 'ReadEvents default mismatch.');
assert(strcmp(ReplayConfig.Channel, 'all'), 'Channel default mismatch.');
assert(isequal(RTConfig.TargetBand, RTIn.TargetBand), 'Processing settings were not preserved.');
assert(strcmp(RTConfig.Spatial.MatrixSource, RTIn.Spatial.MatrixSource), ...
    'Spatial MatrixSource was changed silently.');
assert(RTConfig.Source.CTF.ApplyChannelGains == RTIn.Source.CTF.ApplyChannelGains, ...
    'CTF correction flags were changed silently.');

clear cleanupObj
end

function local_cleanup(pathValue)
if exist(pathValue, 'file') == 2
    delete(pathValue);
end
end
