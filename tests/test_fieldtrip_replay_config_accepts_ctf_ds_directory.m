function test_fieldtrip_replay_config_accepts_ctf_ds_directory()
% TEST_FIELDTRIP_REPLAY_CONFIG_ACCEPTS_CTF_DS_DIRECTORY Check dataset path validation.

%% ===== ACCEPT DIRECTORY DATASET =====
datasetDir = [tempname, '.ds'];
mkdir(datasetDir);
cleanupObj = onCleanup(@() local_cleanup(datasetDir));

[~, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetDir);
assert(strcmp(ReplayConfig.DatasetPath, datasetDir), 'CTF .ds directory was not accepted.');

%% ===== REJECT MISSING DATASET =====
missingPath = [tempname, '.ds'];
didError = false;
try
    nf_local_fieldtrip_replay_config(missingPath);
catch ME
    didError = true;
    assert(contains(ME.message, 'does not exist'), 'Unexpected missing path error: %s', ME.message);
end
assert(didError, 'Missing replay dataset path was accepted.');

clear cleanupObj
end

function local_cleanup(pathValue)
if exist(pathValue, 'dir') == 7
    rmdir(pathValue, 's');
end
end
