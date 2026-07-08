function test_check_config_handles_unfinalized_live_config()
% TEST_CHECK_CONFIG_HANDLES_UNFINALIZED_LIVE_CONFIG Check raw sentinel tolerance.

%% ===== CHECK UNFINALIZED LIVE CONFIG =====
% RequireCTFRes4 = [] is a raw-config sentinel resolved by nf_finalize_config.
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;

assert(isempty(RTConfig.Source.FieldTrip.RequireCTFRes4), ...
    'Raw live config should keep RequireCTFRes4 empty.');
nf_check_config(RTConfig);

end
