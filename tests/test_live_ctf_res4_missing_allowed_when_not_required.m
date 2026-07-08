function test_live_ctf_res4_missing_allowed_when_not_required()
% TEST_LIVE_CTF_RES4_MISSING_ALLOWED_WHEN_NOT_REQUIRED Check optional CTF.

%% ===== MISSING CTF IS RECORDED WHEN OPTIONAL =====
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.RequireCTFRes4 = false;
Header.RawHeader = struct();
Header.Fs = 2400;
Header.NSamples = 1000;
Header.NChannels = 1;
Header.ChannelNames = {'MEG001'};

CTFInfo = nf_live_read_ctf_res4_header(Header, RTConfig);

assert(CTFInfo.HasCTFRes4 == false, 'Missing ctf_res4 was marked present.');
assert(~isempty(CTFInfo.Messages), 'Missing optional ctf_res4 did not add a message.');

end
