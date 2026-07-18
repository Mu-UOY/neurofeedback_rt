function test_live_buffer_reset_resync_policy()
% TEST_LIVE_BUFFER_RESET_RESYNC_POLICY Check explicit reset resync behavior.

state.WaitCalls = 0;
RTConfig = local_config(@fake_buffer);
RTConfig.Source.FieldTrip.BufferResetPolicy = nf_modes().BufferResetPolicy.ResyncToCurrentEnd;
Source = local_source(RTConfig, 1000);

[chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
assert(isempty(chunk), 'Reset resync should return an empty chunk.');
assert(Source.LastSampleRead == 900, 'Reset resync did not move cursor to current end.');
assert(strcmp(Source.LastReadStatus, 'buffer_reset_resynced'), 'Reset status mismatch.');

[chunk2, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
assert(chunk2.SampleIndex == 901, 'Next chunk did not start after resynced cursor.');
assert(isequal(chunk2.FieldTripReadRange, [900 1379]), 'Post-resync transport range mismatch.');
assert(Source.LastSampleRead == 1380, 'Post-resync cursor mismatch.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        switch command
            case 'wait_dat'
                state.WaitCalls = state.WaitCalls + 1;
                if state.WaitCalls == 1
                    hdr.nsamples = 900;
                else
                    hdr.nsamples = arg(1);
                end
                varargout{1} = hdr;
            case 'get_dat'
                nSamples = arg(2) - arg(1) + 1;
                dat.buf = zeros(2, nSamples);
                varargout{1} = dat;
            otherwise
                error('Unexpected fake buffer command: %s', command);
        end
    end
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
