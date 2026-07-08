function test_source_dry_run_fake_header()
% TEST_SOURCE_DRY_RUN_FAKE_HEADER Check acquisition-only dry run.

%% ===== RUN DRY RUN WITHOUT RT PROCESSING =====
state.nsamples = 1480;
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.LiveDryRun.TimeoutSecs = 0.2;

Source = struct();
Source.Mode = RTConfig.Source.Mode;
Source.LiveAdapter = RTConfig.Source.LiveAdapter;
Source.Fs = 2400;
Source.NChannels = 1;
Source.ChannelNames = {'MEG001'};
Source.Header.Fs = 2400;
Source.Header.NSamples = 1000;

DryRun = nf_source_dry_run(Source, RTConfig);

assert(DryRun.SampleCountAdvanced == true, 'Dry run did not detect sample advance.');
assert(DryRun.AcquisitionBlockSamples == 480, 'Dry run detected wrong block size.');
assert(~isfield(DryRun, 'Measure'), 'Dry run should not call RT processing.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        hdr.fsample = 2400;
        hdr.nsamples = state.nsamples;
        hdr.nchans = 1;
        hdr.channel_names = {'MEG001'};
        varargout{1} = hdr;
    end

end
