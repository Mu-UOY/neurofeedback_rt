function test_live_get_chunk_ben_indexing_fake_buffer()
% TEST_LIVE_GET_CHUNK_BEN_INDEXING_FAKE_BUFFER Check preserved get_dat range.

%% ===== READ ONE FAKE LIVE CHUNK =====
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

[chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);

assert(chunk.SampleIndex == 1001, 'Chunk SampleIndex did not use LastSampleRead+1.');
assert(isequal(chunk.SampleIndices, 1001:1480), 'Chunk SampleIndices mismatch.');
assert(chunk.NSamples == RTConfig.ChunkSamples, 'Chunk NSamples mismatch.');
assert(isequal(chunk.BenGetDatRange, [1000 1479]), 'Benjamin get_dat range changed.');
assert(~isempty(chunk.BenIndexingNote), 'Ben indexing note missing.');
assert(Source.LastSampleRead == 1480, 'Live source cursor did not advance.');

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
