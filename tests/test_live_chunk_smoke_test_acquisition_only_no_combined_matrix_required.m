function test_live_chunk_smoke_test_acquisition_only_no_combined_matrix_required()
% TEST_LIVE_CHUNK_SMOKE_TEST_ACQUISITION_ONLY_NO_COMBINED_MATRIX_REQUIRED Check scope.

%% ===== RUN WITHOUT COMBINED MATRIX PATH =====
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

nf_finalize_config(RTConfig);
Result = nf_run_live_chunk_smoke_test(RTConfig);

assert(Result.Pass == true, 'Acquisition-only smoke test did not pass.');
assert(~isfield(Result, 'Spatial'), 'Result should not contain spatial preparation output.');

smokeText = fileread(fullfile(nf_project_root(), 'main', 'nf_run_live_chunk_smoke_test.m'));
assert(~contains(smokeText, 'nf_prepare_live_combined_matrix'), ...
    'Smoke test references spatial preparation.');

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
