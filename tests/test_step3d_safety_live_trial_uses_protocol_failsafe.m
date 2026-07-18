function test_step3d_safety_live_trial_uses_protocol_failsafe()
% TEST_STEP3D_SAFETY_LIVE_TRIAL_USES_PROTOCOL_FAILSAFE Check source of truth.

%% ===== CHECK LIVE AND LEGACY PHASE NAMES =====
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Protocol.Trial.MaxFailsafeSeconds = 17 * 60;
RTConfig.LiveTrial.MaxFailsafeSeconds = 30 * 60;

Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveTrial);
assert(Safety.MaxDurationSeconds == 17 * 60, ...
    'live_trial did not use Protocol.Trial.MaxFailsafeSeconds.');

Safety = nf_safety_init_stop_flag(RTConfig, 'trial');
assert(Safety.MaxDurationSeconds == 17 * 60, ...
    'trial did not use Protocol.Trial.MaxFailsafeSeconds.');

end
