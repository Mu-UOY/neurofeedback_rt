function test_live_header_fingerprint_changes_with_channel_name()
% TEST_LIVE_HEADER_FINGERPRINT_CHANGES_WITH_CHANNEL_NAME Check label sensitivity.

fp1 = nf_live_header_fingerprint(local_header({'MEG001','MEG002'}));
fp2 = nf_live_header_fingerprint(local_header({'MEG001','MEG003'}));
assert(~strcmp(fp1, fp2), 'Header fingerprint did not change with channel name.');
end

function H = local_header(names)
H = struct('Fs', 2400, 'NChannels', numel(names), 'ChannelNames', {names});
end
