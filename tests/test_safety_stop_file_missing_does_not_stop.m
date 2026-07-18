function test_safety_stop_file_missing_does_not_stop()
% TEST_SAFETY_STOP_FILE_MISSING_DOES_NOT_STOP Check absent stop file.

%% ===== CHECK MISSING STOP FILE =====
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Safety.EnableStopFile = true;
RTConfig.Safety.StopFilePath = [tempname, '.stop'];
Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveTrial);

[stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
assert(~stopRequested, 'Missing stop file triggered a stop.');
assert(isempty(Safety.StopReason), 'Missing stop file set a stop reason.');

%% ===== CHECK EMPTY PATH VALIDATION =====
badConfig = nf_mock_live_test_config();
badConfig.Safety.EnableStopFile = true;
badConfig.Safety.StopFilePath = '';

didError = false;
try
    nf_check_config(badConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'StopFilePath'), ...
        'Unexpected empty StopFilePath error: %s', ME.message);
end
assert(didError, 'Enabled stop-file with empty path was accepted.');

end
