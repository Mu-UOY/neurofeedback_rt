function test_live_add_fieldtrip_paths_missing_buffer_errors()
% TEST_LIVE_ADD_FIELDTRIP_PATHS_MISSING_BUFFER_ERRORS Check explicit failure.

%% ===== CHECK MISSING PATH ERROR =====
% With no hook and no configured path, the helper must not guess.
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.Host = 'configured-host';
RTConfig.Source.FieldTrip.Port = 1;
RTConfig.Source.FieldTrip.SettingOrigin.Host = 'config';
RTConfig.Source.FieldTrip.SettingOrigin.Port = 'config';

didError = false;
try
    nf_live_add_fieldtrip_paths(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'BufferMPath') || contains(ME.message, 'FieldTripRoot'), ...
        'Unexpected missing-buffer error: %s', ME.message);
end
assert(didError, 'Missing real buffer path did not error.');

end
