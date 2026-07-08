function test_live_channel_check_fails_gracefully_when_buffer_missing()
% TEST_LIVE_CHANNEL_CHECK_FAILS_GRACEFULLY_WHEN_BUFFER_MISSING Check FAIL report.

%% ===== RUN CHANNEL CHECK WITH MISSING BUFFER PATH =====
RTConfig = nf_live_config();
tempProjectRoot = tempname;
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() rmdir(tempProjectRoot, 's')); %#ok<NASGU>
RTConfig.Paths.ProjectRoot = tempProjectRoot;
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.Host = 'configured-host';
RTConfig.Source.FieldTrip.Port = 1;
RTConfig.Source.FieldTrip.SettingOrigin.Host = 'config';
RTConfig.Source.FieldTrip.SettingOrigin.Port = 'config';
RTConfig.Source.FieldTrip.BufferMPath = '';
RTConfig.Source.FieldTrip.FieldTripRoot = '';
RTConfig.Source.FieldTrip.AllowAlreadyOnPathBuffer = false;

Check = nf_run_live_channel_check(RTConfig);

assert(strcmp(Check.Status, 'FAIL'), 'Missing buffer check did not return FAIL.');
assert(Check.Pass == false, 'Missing buffer check marked Pass.');
assert(isfield(Check.ReportPaths, 'MatPath') && exist(Check.ReportPaths.MatPath, 'file') == 2, ...
    'FAIL MAT report was not saved.');
assert(exist(Check.ReportPaths.TextPath, 'file') == 2, 'FAIL TXT report was not saved.');
assert(exist(Check.ReportPaths.ChannelCsvPath, 'file') == 2, 'FAIL CSV report was not saved.');
assert(~isempty(Check.Messages), 'Caught live error was not recorded.');
assert(contains(Check.Recommendation, 'BufferMPath') || contains(Check.Recommendation, 'FieldTripRoot'), ...
    'Recommendation is not actionable for missing buffer path.');

end
