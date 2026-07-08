function test_live_rt_dry_run_real_buffer_path_not_replaced_by_test_hook()
% TEST_LIVE_RT_DRY_RUN_REAL_BUFFER_PATH_NOT_REPLACED_BY_TEST_HOOK Static production checks.

Modes = nf_modes();
RTConfig = nf_live_config();
assert(isempty(RTConfig.Source.FieldTrip.TestBufferFcn), ...
    'nf_live_config should not set a test hook by default.');

rootDir = fileparts(fileparts(mfilename('fullpath')));
txt = fileread(fullfile(rootDir, 'main', 'nf_run_live_rt_dry_run.m'));

assert(~contains(txt, 'TestBufferFcn'), 'Runner should not assign a test hook.');
assert(~contains(txt, 'mock_live_buffer'), 'Runner should not switch to mock_live_buffer.');
assert(contains(txt, 'Modes.Source.LiveFieldTrip'), 'Runner should use live FieldTrip mode.');
assert(strcmp(Modes.Source.LiveFieldTrip, 'live_fieldtrip'), 'LiveFieldTrip mode constant changed.');
end
