function test_check_config_uses_internal_finalized_flag()
% TEST_CHECK_CONFIG_USES_INTERNAL_FINALIZED_FLAG Check raw/finalized strictness.

%% ===== CHECK RAW CONFIG =====
% Raw configs are allowed to contain unresolved live sentinels.
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;

assert(RTConfig.Internal.IsFinalized == false, 'Live config should start raw.');
nf_check_config(RTConfig);

%% ===== CHECK FINALIZED CONFIG =====
% This dummy file proves only that the path exists.
% Step 3A-0a does not validate precomputed matrix contents or loading.
tmpPath = [tempname, '.mat'];
dummy = 1;
save(tmpPath, 'dummy');
cleanupObj = onCleanup(@() delete(tmpPath));

RTConfig.Spatial.CombinedMatrixPath = tmpPath;
RTConfig = nf_finalize_config(RTConfig);
assert(RTConfig.Internal.IsFinalized == true, 'Config was not finalized.');
nf_check_config(RTConfig);

%% ===== CHECK INVALID FINALIZED CONFIG =====
% Mutating finalized timing should be caught by nf_check_config.
badConfig = RTConfig;
badConfig.Internal.IsFinalized = true;
badConfig.Fs = 1000;

didError = false;
try
    nf_check_config(badConfig);
catch ME
    didError = true;
    assert(contains(ME.message, '2400'), ...
        'Unexpected finalized timing error: %s', ME.message);
end
assert(didError, 'Invalid finalized live config was accepted.');

clear cleanupObj

end
