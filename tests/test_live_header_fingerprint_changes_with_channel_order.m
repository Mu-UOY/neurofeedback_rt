function test_live_header_fingerprint_changes_with_channel_order()
% TEST_LIVE_HEADER_FINGERPRINT_CHANGES_WITH_CHANNEL_ORDER Check order sensitivity.

fp1 = nf_live_header_fingerprint(local_header({'MEG001','MEG002'}));
fp2 = nf_live_header_fingerprint(local_header({'MEG002','MEG001'}));
assert(~strcmp(fp1, fp2), 'Header fingerprint did not change with channel order.');
end

function H = local_header(names)
H = struct('Fs', 2400, 'NChannels', numel(names), 'ChannelNames', {names});
end
