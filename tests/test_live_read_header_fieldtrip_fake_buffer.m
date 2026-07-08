function test_live_read_header_fieldtrip_fake_buffer()
% TEST_LIVE_READ_HEADER_FIELDTRIP_FAKE_BUFFER Check fake header read.

%% ===== READ HEADER THROUGH TEST BUFFER =====
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.LiveDryRun.RequireSamplingRateMatch = true;

Header = nf_live_read_header_fieldtrip(RTConfig);

assert(Header.Fs == 2400, 'Header Fs not parsed.');
assert(Header.NSamples == 1000, 'Header nsamples not parsed.');
assert(Header.NChannels == 2, 'Header nchans not parsed.');
assert(isequal(Header.ChannelNames, {'MEG001','MEG002'}), 'Header labels not parsed.');
assert(strcmp(Header.ResolvedConnection.SelectedBufferFunction, 'test_hook'), ...
    'Header did not record SelectedBufferFunction = test_hook.');
assert(~isfield(Header.ResolvedConnection, 'BufferFunction'), ...
    'Header used deprecated ResolvedConnection.BufferFunction field.');

end

function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
% Return a deterministic fake FieldTrip header.
switch command
    case 'get_hdr'
        hdr.fsample = 2400;
        hdr.nsamples = 1000;
        hdr.nchans = 2;
        hdr.channel_names = {'MEG001','MEG002'};
        varargout{1} = hdr;
    otherwise
        error('Unexpected fake buffer command: %s', command);
end
end
