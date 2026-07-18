function test_processing_hash_ignores_fieldtrip_endpoint()
% TEST_PROCESSING_HASH_IGNORES_FIELDTRIP_ENDPOINT Check endpoint independence.

RTConfigA = local_hash_config('localhost', 1900 + 72, nf_modes().StreamRole.LocalReplay);
RTConfigB = local_hash_config('10.68.1.239', 1973, nf_modes().StreamRole.LiveMEG);

RTA = nf_rt_prepare(RTConfigA);
RTB = nf_rt_prepare(RTConfigB);

assert(strcmp(RTA.ConfigHash, RTB.ConfigHash), ...
    'Processing ConfigHash changed solely due to FieldTrip endpoint.');
assert(~isfield(RTA.ConfigHashInputs, 'Host'), 'Host entered ConfigHashInputs.');
assert(~isfield(RTA.ConfigHashInputs, 'Port'), 'Port entered ConfigHashInputs.');
assert(~isfield(RTA.ConfigHashInputs, 'StreamRole'), 'StreamRole entered ConfigHashInputs.');
end

function RTConfig = local_hash_config(host, port, streamRole)
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.TestBufferFcn = @fake_buffer;
RTConfig.Source.FieldTrip.Host = host;
RTConfig.Source.FieldTrip.Port = port;
RTConfig.Source.FieldTrip.StreamRole = streamRole;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Spatial.CombinedMatrix = [1 0];
RTConfig.Spatial.NChannels = 2;
end

function varargout = fake_buffer(command, arg, host, port) %#ok<INUSD>
varargout{1} = [];
end
