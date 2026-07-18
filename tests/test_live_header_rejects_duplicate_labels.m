function test_live_header_rejects_duplicate_labels()
% TEST_LIVE_HEADER_REJECTS_DUPLICATE_LABELS Check duplicate-label rejection.

RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;

didError = false;
try
    nf_live_read_header_fieldtrip(RTConfig);
catch ME
    didError = true;
    assert(contains(lower(ME.message), 'duplicate'), 'Unexpected duplicate-label error: %s', ME.message);
end
assert(didError, 'Duplicate channel labels were accepted.');
end

function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
hdr.fsample = 2400;
hdr.nsamples = 1000;
hdr.nchans = 2;
hdr.channel_names = {'MEG001','MEG001'};
varargout{1} = hdr;
end
