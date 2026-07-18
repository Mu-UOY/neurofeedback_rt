function test_trial_failsafe_single_source_of_truth()
% TEST_TRIAL_FAILSAFE_SINGLE_SOURCE_OF_TRUTH Check trial failsafe config.

%% ===== CHECK DEFAULT FAILSAFE =====
% Protocol.Trial.MaxFailsafeSeconds is the only Step 3A-0a source of truth.
RTConfig = nf_mock_live_test_config();
assert(RTConfig.Protocol.Trial.MaxFailsafeSeconds == 30 * 60, ...
    'Default trial hard failsafe should be 30 minutes.');
assert(RTConfig.Protocol.Trial.MaxFailsafeSeconds >= 15 * 60, ...
    'Trial hard failsafe should be at least 15 minutes.');
assert(~isfield(RTConfig.Safety, 'MaxDurationSeconds'), ...
    'Safety.MaxDurationSeconds should not be introduced as an independent default.');

%% ===== CHECK LEGACY CONFLICT =====
% A conflicting legacy duration must fail instead of being silently translated.
badConfig = RTConfig;
badConfig.Internal.IsFinalized = false;
badConfig.Safety.MaxDurationSeconds = 60;

didError = false;
try
    nf_finalize_config(badConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'Protocol.Trial.MaxFailsafeSeconds'), ...
        'Unexpected failsafe conflict error: %s', ME.message);
end
assert(didError, 'Conflicting Safety.MaxDurationSeconds was accepted.');

%% ===== CHECK LIVE TRIAL MIRROR CONFLICT =====
% LiveTrial.MaxFailsafeSeconds may exist only as a derived mirror.
badConfig = RTConfig;
badConfig.LiveTrial.MaxFailsafeSeconds = RTConfig.Protocol.Trial.MaxFailsafeSeconds - 1;

didError = false;
try
    nf_check_config(badConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'LiveTrial.MaxFailsafeSeconds'), ...
        'Unexpected LiveTrial mirror conflict error: %s', ME.message);
end
assert(didError, 'Divergent LiveTrial.MaxFailsafeSeconds was accepted.');

end
