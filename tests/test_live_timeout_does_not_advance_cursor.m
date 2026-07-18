function test_live_timeout_does_not_advance_cursor()
% TEST_LIVE_TIMEOUT_DOES_NOT_ADVANCE_CURSOR Check timeout cursor safety.

RTConfig = local_config(@fake_buffer);
Source = local_source(RTConfig, 1000);

[chunk, Source2] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);

assert(isempty(chunk), 'Timeout should return an empty chunk.');
assert(Source2.LastSampleRead == Source.LastSampleRead, 'Timeout advanced LastSampleRead.');
assert(strcmp(Source2.LastError, 'timeout_waiting_for_samples'), 'Timeout LastError mismatch.');
assert(Source2.TimeoutCount == 1, 'TimeoutCount was not incremented.');
end

function RTConfig = local_config(fakeFcn)
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = fakeFcn;
end

function Source = local_source(RTConfig, lastSampleRead)
Source = struct('Mode', RTConfig.Source.Mode, 'LiveAdapter', RTConfig.Source.LiveAdapter, ...
    'LastSampleRead', lastSampleRead, 'TimeoutMs', RTConfig.Source.FieldTrip.TimeoutMs, ...
    'NChannels', 2, 'ChannelNames', {{'MEG001','MEG002'}}, ...
    'ChannelNamesAfterCorrection', {{'MEG001','MEG002'}});
end

function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
switch command
    case 'wait_dat'
        hdr.nsamples = 1200;
        varargout{1} = hdr;
    otherwise
        error('get_dat should not be called on timeout.');
end
end
