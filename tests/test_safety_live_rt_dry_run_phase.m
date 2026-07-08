function test_safety_live_rt_dry_run_phase()
% TEST_SAFETY_LIVE_RT_DRY_RUN_PHASE Check Step 3C safety phase.

RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.LiveRTDryRun.DurationSeconds = 12;

Safety = nf_safety_init_stop_flag(RTConfig, 'live_rt_dry_run');
assert(strcmp(Safety.Phase, 'live_rt_dry_run'), 'Unexpected safety phase.');
assert(Safety.MaxDurationSeconds == RTConfig.LiveRTDryRun.DurationSeconds, ...
    'Safety did not use LiveRTDryRun.DurationSeconds.');

[stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
assert(islogical(stopRequested), 'Stop request was not logical.');
assert(islogical(nf_safety_hard_failsafe_exceeded(Safety)), ...
    'Hard failsafe result was not logical.');
nf_safety_shutdown(Safety);

Safety2 = nf_safety_init_stop_flag(RTConfig, 'live_chunk_smoke_test');
assert(strcmp(Safety2.Phase, 'live_chunk_smoke_test'), ...
    'Smoke-test safety phase regressed.');
nf_safety_shutdown(Safety2);
end
