function test_safety_live_chunk_smoke_test_phase()
% TEST_SAFETY_LIVE_CHUNK_SMOKE_TEST_PHASE Check Step 3B safety helpers.

%% ===== CHECK SAFETY PHASE =====
RTConfig = nf_live_config();
RTConfig.LiveDryRun.DurationSeconds = 5;

Safety = nf_safety_init_stop_flag(RTConfig, 'live_chunk_smoke_test');

assert(strcmp(Safety.Phase, 'live_chunk_smoke_test'), 'Safety phase mismatch.');
assert(isfinite(Safety.MaxDurationSeconds), 'Safety max duration should be finite.');

[stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
assert(islogical(stopRequested), 'stopRequested should be logical.');
assert(islogical(nf_safety_hard_failsafe_exceeded(Safety)), ...
    'Hard failsafe check should return logical.');
nf_safety_shutdown(Safety);

end
