function test_live_add_fieldtrip_paths_uses_test_hook_without_buffer()
% TEST_LIVE_ADD_FIELDTRIP_PATHS_USES_TEST_HOOK_WITHOUT_BUFFER Check test path.

%% ===== CHECK TEST HOOK SHORT-CIRCUIT =====
% A fake buffer function should bypass real buffer.m resolution.
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = @(varargin) [];

PathInfo = nf_live_add_fieldtrip_paths(RTConfig);

assert(strcmp(PathInfo.Status, 'PASS'), 'Test hook path setup did not pass.');
assert(PathInfo.UsedTestHook == true, 'Path setup did not record TestBufferFcn use.');
assert(PathInfo.BufferFound == false, 'Test hook should not require real buffer.m.');

end
