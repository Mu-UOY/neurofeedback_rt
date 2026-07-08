function test_live_source_init_fake_header_sets_cursor()
% TEST_LIVE_SOURCE_INIT_FAKE_HEADER_SETS_CURSOR Check live Source schema.

%% ===== INITIALIZE FROM FAKE HEADER =====
state.getHdrCalls = 0;
RTConfig = local_fake_live_config(@fake_buffer);

Source = nf_source_init('live_fieldtrip', [], RTConfig);

assert(Source.LastSampleRead == 1000, 'Live source did not start after current header sample.');
assert(Source.Fs == 2400, 'Live source Fs mismatch.');
assert(Source.IsLive == true, 'Live source did not mark IsLive.');
assert(isequal(Source.ChannelNames, {'MEG001','MEG002'}), 'Channel names missing.');
assert(isfield(Source, 'RawHeader'), 'RawHeader missing.');
assert(isfield(Source, 'SettingOrigin'), 'SettingOrigin missing.');
assert(isfield(Source, 'ResolvedConnection'), 'ResolvedConnection missing.');
assert(isequal(Source.Host, Source.ResolvedConnection.Host), 'Host alias mismatch.');
assert(isequal(Source.Port, Source.ResolvedConnection.Port), 'Port alias mismatch.');
assert(isequal(Source.TimeoutMs, Source.ResolvedConnection.TimeoutMs), 'Timeout alias mismatch.');

    function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
        switch command
            case 'get_hdr'
                state.getHdrCalls = state.getHdrCalls + 1;
                hdr.fsample = 2400;
                hdr.nsamples = 1000 + 480 * double(state.getHdrCalls > 1);
                hdr.nchans = 2;
                hdr.channel_names = {'MEG001','MEG002'};
                varargout{1} = hdr;
            otherwise
                error('Unexpected fake buffer command: %s', command);
        end
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
