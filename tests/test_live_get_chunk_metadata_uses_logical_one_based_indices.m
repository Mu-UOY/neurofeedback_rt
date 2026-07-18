function test_live_get_chunk_metadata_uses_logical_one_based_indices()
% TEST_LIVE_GET_CHUNK_METADATA_USES_LOGICAL_ONE_BASED_INDICES Check metadata split.

RTConfig = local_config(@fake_buffer);
Source = local_source(RTConfig, 1000);
[chunk, ~] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);

assert(chunk.SampleIndex == 1001, 'chunk.SampleIndex is not logical one-based.');
assert(chunk.SampleIndices(1) == 1001, 'chunk.SampleIndices did not begin at logical start.');
assert(chunk.SampleIndices(end) == 1480, 'chunk.SampleIndices did not end at logical stop.');
assert(isequal(chunk.RequestedGetDatRange, [1000 1479]), 'Transport range mismatch.');
assert(isequal(chunk.FieldTripReadRange, [1000 1479]), 'FieldTripReadRange mismatch.');
assert(~isequal(chunk.SampleIndices([1 end]), chunk.FieldTripReadRange), ...
    'Logical sample metadata was incorrectly set to transport range.');
end

function RTConfig = local_config(fakeFcn)
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = fakeFcn;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.RemoveBlockMean = false;
end

function Source = local_source(RTConfig, lastSampleRead)
Source = struct();
Source.Mode = RTConfig.Source.Mode;
Source.LiveAdapter = RTConfig.Source.LiveAdapter;
Source.LastSampleRead = lastSampleRead;
Source.TimeoutMs = RTConfig.Source.FieldTrip.TimeoutMs;
Source.NChannels = 2;
Source.ChannelNames = {'MEG001','MEG002'};
Source.ChannelNamesAfterCorrection = Source.ChannelNames;
Source.ChannelGains = [];
Source.iMeg = [];
Source.iMegRef = [];
Source.MegRefCoef = [];
end

function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
switch command
    case 'wait_dat'
        hdr.nsamples = arg(1);
        varargout{1} = hdr;
    case 'get_dat'
        nSamples = arg(2) - arg(1) + 1;
        dat.buf = zeros(2, nSamples);
        varargout{1} = dat;
    otherwise
        error('Unexpected fake buffer command: %s', command);
end
end
