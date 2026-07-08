function test_live_rt_dry_run_source_uses_public_dispatchers()
% TEST_LIVE_RT_DRY_RUN_SOURCE_USES_PUBLIC_DISPATCHERS Check live source interface.

rootDir = fileparts(fileparts(mfilename('fullpath')));
txt = fileread(fullfile(rootDir, 'main', 'nf_run_live_rt_dry_run.m'));

assert(contains(txt, 'nf_source_init'), 'Runner does not initialize through public source dispatcher.');
assert(contains(txt, 'nf_get_meg_chunk'), 'Runner does not read through public chunk dispatcher.');
assert(~contains(txt, 'nf_get_meg_chunk_live_fieldtrip_ben'), ...
    'Runner directly calls the live FieldTrip helper.');
assert(~contains(txt, 'nf_live_buffer_call'), 'Runner directly calls the live buffer wrapper.');
assert(~contains(lower(txt), 'fake'), 'Runner references test-buffer helpers.');
end
