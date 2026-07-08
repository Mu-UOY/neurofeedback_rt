function test_live_ctf_res4_missing_errors_when_required()
% TEST_LIVE_CTF_RES4_MISSING_ERRORS_WHEN_REQUIRED Check required CTF.

%% ===== MISSING CTF FAILS WHEN REQUIRED =====
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.RequireCTFRes4 = true;
Header.RawHeader = struct();
Header.Fs = 2400;
Header.NSamples = 1000;
Header.NChannels = 1;
Header.ChannelNames = {'MEG001'};

didError = false;
try
    nf_live_read_ctf_res4_header(Header, RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'ctf_res4'), ...
        'Unexpected required ctf_res4 error: %s', ME.message);
end
assert(didError, 'Missing required ctf_res4 did not error.');

end
