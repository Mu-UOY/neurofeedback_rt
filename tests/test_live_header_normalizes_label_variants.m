function test_live_header_normalizes_label_variants()
% TEST_LIVE_HEADER_NORMALIZES_LABEL_VARIANTS Check common header aliases.

RTConfig = local_config(@buffer_a);
HeaderA = nf_live_read_header_fieldtrip(RTConfig);

RTConfig.Source.FieldTrip.TestBufferFcn = @buffer_b;
HeaderB = nf_live_read_header_fieldtrip(RTConfig);

assert(isequal(HeaderA.ChannelNames, {'MEG001','MEG002'}), 'channel_names not normalized.');
assert(isequal(HeaderB.ChannelNames, {'MEG001','MEG002'}), 'label not normalized.');
assert(strcmp(HeaderA.StructuralFingerprint, HeaderB.StructuralFingerprint), ...
    'Equivalent label variants produced different fingerprints.');
end

function RTConfig = local_config(fakeFcn)
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.TestBufferFcn = fakeFcn;
end

function varargout = buffer_a(command, arg, host, port) %#ok<INUSD>
hdr.fsample = 2400;
hdr.nsamples = 1000;
hdr.nchans = 2;
hdr.channel_names = {'MEG001','MEG002'};
varargout{1} = hdr;
end

function varargout = buffer_b(command, arg, host, port) %#ok<INUSD>
hdr.Fs = 2400;
hdr.nSamples = 2000;
hdr.nChans = 2;
hdr.label = ["MEG001"; "MEG002"];
varargout{1} = hdr;
end
