function test_live_channel_check_rethrows_if_report_save_fails()
% TEST_LIVE_CHANNEL_CHECK_RETHROWS_IF_REPORT_SAVE_FAILS Check save failure.

%% ===== REPORT SAVE FAILURE IS CLEAR =====
RTConfig = nf_live_config();
Check.Status = 'FAIL';
Check.Pass = false;
Session.ReportsDir = [tempname '_missing_reports'];

didError = false;
try
    nf_save_live_channel_check(Check, RTConfig, Session);
catch ME
    didError = true;
    assert(contains(ME.message, 'ReportsDir'), ...
        'Unexpected report-save failure error: %s', ME.message);
end
assert(didError, 'Report save failure was not rethrown.');

end
