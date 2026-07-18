function test_live_buffer_reset_errors_by_default()
% TEST_LIVE_BUFFER_RESET_ERRORS_BY_DEFAULT Check fail-closed reset policy.

RTConfig = local_config(@fake_buffer);
Source = local_source(RTConfig, 1000);

didError = false;
try
    nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
catch ME
    didError = true;
    assert(contains(lower(ME.message), 'buffer reset'), 'Unexpected reset error: %s', ME.message);
end
assert(didError, 'Buffer reset did not error by default.');
assert(Source.LastSampleRead == 1000, 'Caller cursor advanced after reset error.');
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
hdr.nsamples = 900;
varargout{1} = hdr;
end
