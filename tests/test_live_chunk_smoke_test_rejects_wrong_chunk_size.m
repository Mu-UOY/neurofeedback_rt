function test_live_chunk_smoke_test_rejects_wrong_chunk_size()
% TEST_LIVE_CHUNK_SMOKE_TEST_REJECTS_WRONG_CHUNK_SIZE Check size failure.

%% ===== RUN WRONG-SIZE CASE =====
state.getHdrCalls = 0;
state.getDatCalls = 0;
[RTConfig, cleanupObj] = local_smoke_config(@fake_buffer, 4); %#ok<NASGU>

Result = nf_run_live_chunk_smoke_test(RTConfig);

assert(Result.Pass == false, 'Wrong-size smoke test passed unexpectedly.');
assert(Result.ChunkSizePass == false, 'Chunk size pass flag did not fail.');
assert(Result.NInvalidChunks >= 1, 'Wrong-size chunk was not invalid.');
assert(contains(strjoin(Result.Messages, ' '), 'Expected') && ...
    contains(strjoin(Result.Messages, ' '), 'samples'), ...
    'Wrong-size message did not include expected/actual samples.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        switch command
            case 'get_hdr'
                state.getHdrCalls = state.getHdrCalls + 1;
                varargout{1} = local_hdr(1000 + 480 * double(state.getHdrCalls > 1), 3);
            case 'wait_dat'
                varargout{1} = local_hdr(arg(1), 3);
            case 'get_dat'
                state.getDatCalls = state.getDatCalls + 1;
                nSamples = arg(2) - arg(1) + 1;
                if state.getDatCalls == 2
                    nSamples = nSamples - 1;
                end
                dat.buf = repmat(1:nSamples, 3, 1);
                varargout{1} = dat;
            otherwise
                error('Unexpected fake buffer command: %s', command);
        end
    end

end

function [RTConfig, cleanupObj] = local_smoke_config(fakeFcn, nChunks)
% Build a temp-root fake live config.
Modes = nf_modes();
RTConfig = nf_live_config();
tempProjectRoot = tempname;
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() rmdir(tempProjectRoot, 's')); %#ok<NASGU>
RTConfig.Paths.ProjectRoot = tempProjectRoot;
RTConfig.Session.Mode = Modes.Session.LiveChunkSmokeTest;
RTConfig.LiveChunkSmokeTest.NChunks = nChunks;
RTConfig.LiveDryRun.DurationSeconds = 5;
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.TestBufferFcn = fakeFcn;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = '';
end

function hdr = local_hdr(nsamples, nChannels)
% Create a fake FieldTrip header.
hdr.fsample = 2400;
hdr.nsamples = nsamples;
hdr.nchans = nChannels;
hdr.channel_names = arrayfun(@(i) sprintf('MEG%03d', i), 1:nChannels, 'UniformOutput', false);
end
