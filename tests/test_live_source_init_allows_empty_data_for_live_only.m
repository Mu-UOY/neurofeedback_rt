function test_live_source_init_allows_empty_data_for_live_only()
% TEST_LIVE_SOURCE_INIT_ALLOWS_EMPTY_DATA_FOR_LIVE_ONLY Check dispatch order.

%% ===== LIVE FIELDTRIP ACCEPTS EMPTY DATA WITH TEST HOOK =====
state.getHdrCalls = 0;
RTConfig = local_fake_live_config(@fake_buffer);
Source = nf_source_init('live_fieldtrip', [], RTConfig);
assert(Source.IsLive == true, 'live_fieldtrip did not initialize with empty Data.');

%% ===== SIMULATED MODE STILL REQUIRES DATA.X =====
didError = false;
try
    nf_source_init('simulated_online', [], RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'Data.X'), ...
        'Unexpected simulated empty-data error: %s', ME.message);
end
assert(didError, 'simulated_online accepted empty Data.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        state.getHdrCalls = state.getHdrCalls + 1;
        hdr.fsample = 2400;
        hdr.nsamples = 1000 + 480 * double(state.getHdrCalls > 1);
        hdr.nchans = 1;
        hdr.channel_names = {'MEG001'};
        varargout{1} = hdr;
    end

end

function RTConfig = local_fake_live_config(fakeFcn)
% Build a quiet live config using TestBufferFcn.
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.TestBufferFcn = fakeFcn;
RTConfig.Source.FieldTrip.SettingOrigin.Host = 'test_hook';
RTConfig.Source.FieldTrip.SettingOrigin.Port = 'test_hook';
end
