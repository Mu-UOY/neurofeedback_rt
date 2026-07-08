function test_live_detect_acq_block_size_fake_advance()
% TEST_LIVE_DETECT_ACQ_BLOCK_SIZE_FAKE_ADVANCE Check block detection.

%% ===== SAMPLE ADVANCE IS DETECTED =====
state.nsamples = 1000;
state.advance = true;
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.LiveDryRun.TimeoutSecs = 0.2;
Header0.Fs = 2400;
Header0.NSamples = 1000;

BlockInfo = nf_live_detect_acq_block_size(RTConfig, Header0);

assert(BlockInfo.SampleCountAdvanced == true, 'Sample count advance was not detected.');
assert(BlockInfo.AcquisitionBlockSamples == 480, 'Wrong acquisition block size.');

%% ===== FAILURE TO ADVANCE IS RECORDED NOT THROWN =====
state.nsamples = 1000;
state.advance = false;
RTConfig.LiveDryRun.TimeoutSecs = 0.05;
BlockInfo = nf_live_detect_acq_block_size(RTConfig, Header0);
assert(BlockInfo.SampleCountAdvanced == false, 'No-advance case was marked advanced.');
assert(BlockInfo.Timeout == true, 'No-advance case did not record timeout.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        switch command
            case 'get_hdr'
                if state.advance
                    state.nsamples = 1480;
                end
                hdr.fsample = 2400;
                hdr.nsamples = state.nsamples;
                hdr.nchans = 1;
                hdr.channel_names = {'MEG001'};
                varargout{1} = hdr;
            otherwise
                error('Unexpected fake buffer command: %s', command);
        end
    end

end
