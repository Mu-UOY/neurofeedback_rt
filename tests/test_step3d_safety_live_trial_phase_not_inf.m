function test_step3d_safety_live_trial_phase_not_inf()
% TEST_STEP3D_SAFETY_LIVE_TRIAL_PHASE_NOT_INF Check live phase failsafe.

%% ===== CHECK LIVE TRIAL FAILSAFE =====
Modes = nf_modes();
RTConfig = nf_live_config();
Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveTrial);

assert(isfinite(Safety.MaxDurationSeconds), ...
    'live_trial MaxDurationSeconds unexpectedly resolved to Inf.');
assert(Safety.MaxDurationSeconds == RTConfig.Protocol.Trial.MaxFailsafeSeconds, ...
    'live_trial MaxDurationSeconds does not match protocol failsafe.');

Safety.MaxDurationSeconds = -eps;
assert(nf_safety_hard_failsafe_exceeded(Safety), ...
    'Hard failsafe did not trigger after elapsed duration exceeded limit.');

end
