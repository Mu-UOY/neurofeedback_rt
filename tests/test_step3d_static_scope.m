function test_step3d_static_scope()
% TEST_STEP3D_STATIC_SCOPE Check live self-test static architecture boundaries.

rootDir = fileparts(fileparts(mfilename('fullpath')));
selfTestText = fileread(fullfile(rootDir, 'main', 'nf_run_live_self_test.m'));
restText = fileread(fullfile(rootDir, 'main', 'nf_run_live_resting.m'));
trialText = fileread(fullfile(rootDir, 'main', 'nf_run_live_trial.m'));
rtText = fileread(fullfile(rootDir, 'rt', 'nf_rt_process_chunk.m'));

assert(~contains(selfTestText, 'TestBufferFcn ='), 'Production self-test assigns TestBufferFcn.');
assert(contains(selfTestText, 'nf_source_init'), 'Self-test does not use source dispatcher.');
assert(contains(restText, 'nf_get_meg_chunk'), 'Resting does not use public chunk dispatcher.');
assert(contains(trialText, 'nf_get_meg_chunk'), 'Trial does not use public chunk dispatcher.');
assert(contains(restText, 'nf_rt_process_chunk'), 'Resting does not use RT core.');
assert(contains(trialText, 'nf_rt_process_chunk'), 'Trial does not use RT core.');
assert(contains(trialText, 'nf_feedback_map_to_display'), 'Trial does not map feedback outside RT core.');
assert(~contains(rtText, 'nf_feedback_map_to_display'), 'RT core contains feedback mapping.');
assert(~contains(rtText, 'nf_feedback_update'), 'RT core contains feedback update.');
assert(~contains(selfTestText, 'mock_live_buffer'), 'Self-test switches to mock_live_buffer.');
assert(~contains(trialText, '5 * 60'), 'Trial introduced a short cap.');
assert(~contains(trialText, '3 * 60'), 'Trial introduced a short cap.');
assert(~contains(trialText, '180'), 'Trial introduced a 180-second cap literal.');
assert(~contains(trialText, '300'), 'Trial introduced a 300-second cap literal.');
assert(~contains(trialText, 'LiveTrial.MaxFailsafeSeconds'), ...
    'Trial runtime reads LiveTrial.MaxFailsafeSeconds instead of Protocol.Trial.MaxFailsafeSeconds.');
assert(contains(trialText, 'Protocol.Trial.MaxFailsafeSeconds'), ...
    'Trial runtime does not use Protocol.Trial.MaxFailsafeSeconds.');
end
