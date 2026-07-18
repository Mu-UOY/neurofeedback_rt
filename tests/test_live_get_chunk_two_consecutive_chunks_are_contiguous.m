function test_live_get_chunk_two_consecutive_chunks_are_contiguous()
% TEST_LIVE_GET_CHUNK_TWO_CONSECUTIVE_CHUNKS_ARE_CONTIGUOUS Check no overlap/gap.

%% ===== READ TWO FAKE CHUNKS =====
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.RemoveBlockMean = false;

Source = struct();
Source.Mode = RTConfig.Source.Mode;
Source.LiveAdapter = RTConfig.Source.LiveAdapter;
Source.LastSampleRead = 1000;
Source.TimeoutMs = RTConfig.Source.FieldTrip.TimeoutMs;
Source.ChannelNames = {'MEG001','MEG002'};
Source.ChannelNamesAfterCorrection = Source.ChannelNames;
Source.ChannelGains = [];
Source.iMeg = [];
Source.iMegRef = [];
Source.MegRefCoef = [];

[chunk1, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
[chunk2, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);

%% ===== CHECK CONTIGUITY =====
assert(chunk2.SampleIndices(1) == chunk1.SampleIndices(end) + 1, ...
    'Consecutive live chunks overlapped or left a gap.');
assert(numel(intersect(chunk1.SampleIndices, chunk2.SampleIndices)) == 0, ...
    'Consecutive live chunks overlap.');
assert(strcmp(chunk1.IndexingMode, 'fieldtrip_zero_based_transport_matlab_one_based_logical_v1'), ...
    'Indexing audit mode was not preserved.');
assert(strcmp(chunk2.IndexingMode, chunk1.IndexingMode), ...
    'Indexing audit mode changed between chunks.');
assert(Source.LastClaimedSampleRead == chunk2.SampleIndices(end), ...
    'Source did not record second chunk final claimed sample.');

end

function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
% Return wait_dat headers and deterministic get_dat samples.
switch command
    case 'wait_dat'
        hdr.nsamples = arg(1);
        varargout{1} = hdr;
    case 'get_dat'
        nSamples = arg(2) - arg(1) + 1;
        dat.buf = reshape(1:(2 * nSamples), 2, nSamples);
        varargout{1} = dat;
    otherwise
        error('Unexpected fake buffer command: %s', command);
end
end
