function test_live_get_chunk_reports_indexing_mode()
% TEST_LIVE_GET_CHUNK_REPORTS_INDEXING_MODE Check FieldTrip indexing audit.

%% ===== READ FAKE CHUNK =====
[chunk, Source] = local_read_chunk(1000);

assert(isfield(chunk, 'IndexingMode'), 'Chunk is missing IndexingMode.');
assert(strcmp(chunk.IndexingMode, 'fieldtrip_zero_based_transport_matlab_one_based_logical_v1'), ...
    'Unexpected chunk indexing mode.');
assert(isfield(Source, 'IndexingMode'), 'Source is missing IndexingMode.');
assert(strcmp(Source.IndexingMode, chunk.IndexingMode), ...
    'Source indexing mode did not mirror chunk indexing mode.');
assert(isfield(chunk, 'Messages') && ~isempty(chunk.Messages), ...
    'Chunk is missing indexing confirmation message.');
assert(contains(chunk.Messages{1}, 'zero-based'), ...
    'Indexing message does not describe transport convention.');

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
