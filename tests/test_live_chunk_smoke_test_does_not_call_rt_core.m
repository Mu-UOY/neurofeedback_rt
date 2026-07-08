function test_live_chunk_smoke_test_does_not_call_rt_core()
% TEST_LIVE_CHUNK_SMOKE_TEST_DOES_NOT_CALL_RT_CORE Check Step 3B boundary.

%% ===== STATIC SCAN RUNNER =====
runnerPath = fullfile(nf_project_root(), 'main', 'nf_run_live_chunk_smoke_test.m');
runnerText = fileread(runnerPath);
forbidden = { ...
    'nf_rt_process_chunk', ...
    'nf_rt_prepare', ...
    'nf_rt_apply_spatial', ...
    'nf_rt_filter_apply', ...
    'nf_rt_compute_power', ...
    'nf_rt_compute_zscore', ...
    'nf_feedback_update', ...
    'nf_feedback_map_to_display', ...
    'nf_prepare_live_combined_matrix'};
for iForbidden = 1:numel(forbidden)
    assert(~contains(runnerText, forbidden{iForbidden}), ...
        'Smoke runner references forbidden function: %s', forbidden{iForbidden});
end

%% ===== RUN FAKE SMOKE TEST =====
state.getHdrCalls = 0;
Modes = nf_modes();
RTConfig = nf_live_config();
tempProjectRoot = tempname;
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() rmdir(tempProjectRoot, 's')); %#ok<NASGU>
RTConfig.Paths.ProjectRoot = tempProjectRoot;
RTConfig.Session.Mode = Modes.Session.LiveChunkSmokeTest;
RTConfig.LiveChunkSmokeTest.NChunks = 2;
RTConfig.LiveDryRun.DurationSeconds = 5;
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = '';

Result = nf_run_live_chunk_smoke_test(RTConfig);

assert(~isfield(Result, 'Measure'), 'Smoke result should not contain Measure.');
assert(~isfield(Result, 'RT'), 'Smoke result should not contain RT.');
assert(~isfield(Result, 'Baseline'), 'Smoke result should not contain Baseline.');
assert(~isfield(Result, 'Trial'), 'Smoke result should not contain Trial.');
assert(~isfield(Result, 'Feedback'), 'Smoke result should not contain Feedback.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        switch command
            case 'get_hdr'
                state.getHdrCalls = state.getHdrCalls + 1;
                varargout{1} = local_hdr(1000 + 480 * double(state.getHdrCalls > 1));
            case 'wait_dat'
                varargout{1} = local_hdr(arg(1));
            case 'get_dat'
                nSamples = arg(2) - arg(1) + 1;
                dat.buf = repmat(1:nSamples, 2, 1);
                varargout{1} = dat;
            otherwise
                error('Unexpected fake buffer command: %s', command);
        end
    end

end

function hdr = local_hdr(nsamples)
% Create a fake FieldTrip header.
hdr.fsample = 2400;
hdr.nsamples = nsamples;
hdr.nchans = 2;
hdr.channel_names = {'MEG001','MEG002'};
end
