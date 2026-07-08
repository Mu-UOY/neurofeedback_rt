function test_save_live_channel_check_requires_existing_session()
% TEST_SAVE_LIVE_CHANNEL_CHECK_REQUIRES_EXISTING_SESSION Check no session creation.

%% ===== MISSING SESSION REPORTS DIR FAILS =====
RTConfig = nf_live_config();
Check.Status = 'FAIL';
Check.Pass = false;

didError = false;
try
    nf_save_live_channel_check(Check, RTConfig, struct());
catch ME
    didError = true;
    assert(contains(ME.message, 'Session.ReportsDir'), ...
        'Unexpected missing-session error: %s', ME.message);
end
assert(didError, 'Save helper accepted missing Session.ReportsDir.');

end
