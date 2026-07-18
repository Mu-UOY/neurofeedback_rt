function test_live_malformed_get_dat_does_not_advance_cursor()
% TEST_LIVE_MALFORMED_GET_DAT_DOES_NOT_ADVANCE_CURSOR Check failed read safety.

RTConfig = local_config(@fake_buffer);
Source = local_source(RTConfig, 1000);

didError = false;
try
    nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'returned 479 samples'), ...
        'Unexpected malformed get_dat error: %s', ME.message);
end
assert(didError, 'Malformed get_dat was accepted.');
assert(Source.LastSampleRead == 1000, 'Caller cursor advanced after failed get_dat.');
end

function RTConfig = local_config(fakeFcn)
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = fakeFcn;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.RemoveBlockMean = false;
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
        hdr.nsamples = arg(1);
        varargout{1} = hdr;
    case 'get_dat'
        dat.buf = zeros(2, 479);
        varargout{1} = dat;
    otherwise
        error('Unexpected fake buffer command: %s', command);
end
end
