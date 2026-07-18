function test_live_header_fingerprint_changes_with_fs()
% TEST_LIVE_HEADER_FINGERPRINT_CHANGES_WITH_FS Check Fs sensitivity.

fp1 = nf_live_header_fingerprint(local_header(2400));
fp2 = nf_live_header_fingerprint(local_header(1200));
assert(~strcmp(fp1, fp2), 'Header fingerprint did not change with Fs.');
end

function H = local_header(fs)
H = struct('Fs', fs, 'NChannels', 2, 'ChannelNames', {{'MEG001','MEG002'}});
end
