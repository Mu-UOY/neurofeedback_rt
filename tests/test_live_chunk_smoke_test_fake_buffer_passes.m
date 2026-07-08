function test_live_chunk_smoke_test_fake_buffer_passes()
% TEST_LIVE_CHUNK_SMOKE_TEST_FAKE_BUFFER_PASSES Check valid fake chunks.

%% ===== RUN VALID FAKE SMOKE TEST =====
state.getHdrCalls = 0;
state.getDatCalls = 0;
[RTConfig, cleanupObj] = local_smoke_config(@fake_buffer, 5); %#ok<NASGU>

Result = nf_run_live_chunk_smoke_test(RTConfig);

assert(Result.Pass == true, 'Valid fake smoke test did not pass.');
assert(Result.NReadChunks == 5, 'Wrong number of chunks read.');
assert(Result.NTimeouts == 0, 'Unexpected timeout count.');
assert(Result.NInvalidChunks == 0, 'Unexpected invalid chunk count.');
assert(Result.ChunkSizePass == true, 'Chunk size check failed.');
assert(Result.ChannelCountStablePass == true, 'Channel count stability failed.');
assert(Result.InternalChunkContinuityPass == true, 'Internal continuity failed.');
assert(Result.CrossChunkContinuityPass == true, 'Cross-chunk continuity failed.');
assert(exist(Result.ReportMatPath, 'file') == 2, 'MAT report missing.');
assert(exist(Result.ReportTextPath, 'file') == 2, 'TXT report missing.');
assert(exist(Result.MetadataCsvPath, 'file') == 2, 'CSV metadata missing.');
assert(height(Result.MetadataTable) == 5, 'Metadata table should have five rows.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        switch command
            case 'get_hdr'
                state.getHdrCalls = state.getHdrCalls + 1;
                hdr = local_hdr(1000 + 480 * double(state.getHdrCalls > 1), 3);
                varargout{1} = hdr;
            case 'wait_dat'
                varargout{1} = local_hdr(arg(1), 3);
            case 'get_dat'
                state.getDatCalls = state.getDatCalls + 1;
                nSamples = arg(2) - arg(1) + 1;
                dat.buf = repmat(1:nSamples, 3, 1) + state.getDatCalls;
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
RTConfig.LiveChunkSmokeTest.SaveFirstChunkPreview = true;
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
