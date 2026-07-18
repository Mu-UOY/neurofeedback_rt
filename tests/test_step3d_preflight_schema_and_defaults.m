function test_step3d_preflight_schema_and_defaults()
% TEST_STEP3D_PREFLIGHT_SCHEMA_AND_DEFAULTS Check default false preflight schema.

[RTConfig, tempRoot] = nf_test_live_self_test_config();
cleanupObj = onCleanup(@() local_cleanup(tempRoot));

assert(RTConfig.LiveSelfTest.RunPreflightDiagnostics == false, 'Diagnostics preflight default changed.');
assert(RTConfig.LiveSelfTest.RunChannelCheck == false, 'Channel check preflight default changed.');
assert(RTConfig.LiveSelfTest.RunChunkSmokeTest == false, 'Chunk smoke preflight default changed.');
assert(RTConfig.LiveSelfTest.RunRTDryRun == false, 'RT dry-run preflight default changed.');

Result = nf_run_live_self_test(RTConfig);
assert(isfield(Result, 'Preflight'), 'Result missing Preflight.');
assert(strcmp(Result.Preflight.Type, 'preflight_result'), 'Unexpected preflight type.');
assert(Result.Preflight.Ran == false, 'Preflight ran despite default false flags.');
assert(Result.Preflight.Pass == true, 'Default preflight should pass.');

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
