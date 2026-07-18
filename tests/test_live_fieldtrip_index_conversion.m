function test_live_fieldtrip_index_conversion()
% TEST_LIVE_FIELDTRIP_INDEX_CONVERSION Check logical/transport mapping.

[chunk, Source] = local_read_chunk(1000);

assert(chunk.LogicalStartSample == 1001, 'Logical start mismatch.');
assert(chunk.LogicalStopSample == 1480, 'Logical stop mismatch.');
assert(chunk.SampleIndex == 1001, 'SampleIndex should be one-based logical start.');
assert(isequal(chunk.SampleIndices, 1001:1480), 'Logical sample indices mismatch.');
assert(isequal(chunk.FieldTripReadRange, [1000 1479]), 'Zero-based transport range mismatch.');
assert(Source.LastSampleRead == 1480, 'Source cursor should record logical stop.');
end

function [chunk, Source] = local_read_chunk(lastSampleRead)
RTConfig = local_config(@fake_buffer);
Source = local_source(RTConfig, lastSampleRead);
[chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
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
