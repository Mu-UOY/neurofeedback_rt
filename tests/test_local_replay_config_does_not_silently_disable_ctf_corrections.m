function test_local_replay_config_does_not_silently_disable_ctf_corrections()
% TEST_LOCAL_REPLAY_CONFIG_DOES_NOT_SILENTLY_DISABLE_CTF_CORRECTIONS Check preservation.

datasetPath = [tempname, '.mat'];
save(datasetPath, 'datasetPath');
cleanupObj = onCleanup(@() local_cleanup(datasetPath));

RTIn = nf_live_config();
RTIn.Source.CTF.ApplyChannelGains = true;
RTIn.Source.CTF.ApplyMegRefCorrection = true;
RTIn.Source.CTF.ApplyProjector = true;

RTConfig = nf_local_fieldtrip_replay_config(datasetPath, RTIn);

assert(RTConfig.Source.CTF.ApplyChannelGains == true, 'ApplyChannelGains was disabled silently.');
assert(RTConfig.Source.CTF.ApplyMegRefCorrection == true, 'ApplyMegRefCorrection was disabled silently.');
assert(RTConfig.Source.CTF.ApplyProjector == true, 'ApplyProjector was disabled silently.');

clear cleanupObj
end

function local_cleanup(pathValue)
if exist(pathValue, 'file') == 2
    delete(pathValue);
end
end
