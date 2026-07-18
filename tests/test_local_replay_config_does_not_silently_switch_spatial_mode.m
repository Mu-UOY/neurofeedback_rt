function test_local_replay_config_does_not_silently_switch_spatial_mode()
% TEST_LOCAL_REPLAY_CONFIG_DOES_NOT_SILENTLY_SWITCH_SPATIAL_MODE Check preservation.

Modes = nf_modes();
datasetPath = [tempname, '.mat'];
save(datasetPath, 'datasetPath');
cleanupObj = onCleanup(@() local_cleanup(datasetPath));

RTIn = nf_live_config();
RTIn.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTIn.Spatial.CombinedMatrixPath = 'operator_matrix.mat';

RTConfig = nf_local_fieldtrip_replay_config(datasetPath, RTIn);

assert(strcmp(RTConfig.Spatial.MatrixSource, Modes.Spatial.MatrixSource.Precomputed), ...
    'Spatial.MatrixSource was switched silently.');
assert(strcmp(RTConfig.Spatial.CombinedMatrixPath, 'operator_matrix.mat'), ...
    'Spatial.CombinedMatrixPath was changed silently.');

clear cleanupObj
end

function local_cleanup(pathValue)
if exist(pathValue, 'file') == 2
    delete(pathValue);
end
end
