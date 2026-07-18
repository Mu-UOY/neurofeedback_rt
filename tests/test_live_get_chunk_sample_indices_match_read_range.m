function test_live_get_chunk_sample_indices_match_read_range()
% TEST_LIVE_GET_CHUNK_SAMPLE_INDICES_MATCH_READ_RANGE Check chunk audit range.

%% ===== READ FAKE CHUNK =====
[chunk, Source] = local_read_chunk(240);

assert(isequal(chunk.SampleIndices([1 end]), chunk.FieldTripReadRange + 1), ...
    'Logical SampleIndices do not align with zero-based FieldTripReadRange.');
assert(isequal(chunk.ReadRangeSamples, chunk.FieldTripReadRange), ...
    'ReadRangeSamples should be transport-range audit metadata.');
assert(chunk.NSamples == numel(chunk.SampleIndices), ...
    'chunk.NSamples does not match SampleIndices length.');
assert(chunk.NSamples == size(chunk.Data, 2), ...
    'chunk.NSamples does not match Data sample count.');
assert(Source.LastClaimedSampleRead == chunk.SampleIndices(end), ...
    'Source.LastClaimedSampleRead did not record final claimed sample.');
assert(Source.LastSampleRead == chunk.SampleIndices(end), ...
    'Source.LastSampleRead did not record last consumed logical sample.');

end

function [chunk, Source] = local_read_chunk(lastSampleRead)
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.RemoveBlockMean = false;

Source = struct();
Source.Mode = RTConfig.Source.Mode;
Source.LiveAdapter = RTConfig.Source.LiveAdapter;
Source.LastSampleRead = lastSampleRead;
Source.TimeoutMs = RTConfig.Source.FieldTrip.TimeoutMs;
Source.ChannelNames = {'MEG001','MEG002'};
Source.ChannelNamesAfterCorrection = Source.ChannelNames;
Source.ChannelGains = [];
Source.iMeg = [];
Source.iMegRef = [];
Source.MegRefCoef = [];

[chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
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
