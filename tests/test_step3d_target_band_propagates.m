function test_step3d_target_band_propagates()
% TEST_STEP3D_TARGET_BAND_PROPAGATES Check target band reaches baseline/trial audit.

[RTConfig, tempRoot] = nf_test_live_self_test_config();
cleanupObj = onCleanup(@() local_cleanup(tempRoot));
RTConfig.TargetBand = [8 12];
RTConfig.TargetBandLabel = 'alpha';

Result = nf_run_live_self_test(RTConfig);
loaded = load(Result.BaselinePath, 'Baseline');
Baseline = loaded.Baseline;

assert(isequal(Baseline.Metadata.TargetBand, [8 12]), 'Baseline target band did not update.');
assert(isequal(Result.RestingResult.TargetBand, [8 12]), 'Resting target band did not update.');
assert(isequal(Result.TrialResult.TargetBand, [8 12]), 'Trial target band did not update.');
assert(strcmp(Result.TrialResult.TargetBandLabel, 'alpha'), 'Trial target band label did not update.');

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
