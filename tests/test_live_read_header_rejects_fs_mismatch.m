function test_live_read_header_rejects_fs_mismatch()
% TEST_LIVE_READ_HEADER_REJECTS_FS_MISMATCH Check strict Fs validation.

%% ===== WRONG FS FAILS WHEN REQUIRED =====
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.LiveDryRun.RequireSamplingRateMatch = true;

didError = false;
try
    nf_live_read_header_fieldtrip(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'Fs mismatch'), ...
        'Unexpected Fs mismatch error: %s', ME.message);
end
assert(didError, 'Wrong live header Fs was accepted.');

end

function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
% Return a wrong-Fs fake FieldTrip header.
hdr.fsample = 1200;
hdr.nsamples = 1000;
hdr.nchans = 1;
hdr.channel_names = {'MEG001'};
varargout{1} = hdr;
end
