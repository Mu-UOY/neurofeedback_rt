function test_live_header_fingerprint_ignores_nsamples()
% TEST_LIVE_HEADER_FINGERPRINT_IGNORES_NSAMPLES Check volatile cursor exclusion.

H1 = local_header(2400, {'MEG001','MEG002'}, 1000);
H2 = local_header(2400, {'MEG001','MEG002'}, 2000);

fp1 = nf_live_header_fingerprint(H1);
fp2 = nf_live_header_fingerprint(H2);
assert(strcmp(fp1, fp2), 'Header fingerprint changed with NSamples.');
end

function H = local_header(fs, names, nSamples)
H = struct('Fs', fs, 'NChannels', numel(names), 'ChannelNames', {names}, 'NSamples', nSamples);
end
