function test_filter_empirical_delay_config_propagates_to_measure()
% TEST_FILTER_EMPIRICAL_DELAY_CONFIG_PROPAGATES_TO_MEASURE Check delay metadata.
%
% USAGE:  test_filter_empirical_delay_config_propagates_to_measure()
%
% DESCRIPTION:
%     Verifies that RTConfig.Filter.EmpiricalDelaySamples and
%     DelayCorrectionUsed propagate through RT.Filter into emitted Measures.

%% ===== BUILD SYNTHETIC STREAM =====
% Passthrough filtering isolates delay metadata propagation.
Fs = 100;
nSamples = 120;
t = (0:(nSamples - 1)) ./ Fs;
Data = struct();
Data.X = sin(2 .* pi .* 10 .* t);
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001'};
Data.Events = [];

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Filter.Type = 'none';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Filter.EmpiricalDelaySamples = 37;
RTConfig.Filter.DelayCorrectionUsed = 37;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.TargetBand = [8 12];
RTConfig.ChunkSamples = 20;
RTConfig.PowerWindowSamples = 40;
RTConfig.BufferSamples = 80;

Source = nf_source_init('simulated_online', Data, RTConfig);
RT = nf_rt_prepare(RTConfig);

ValidMeasures = repmat(nf_measure_empty(), 1, 0);
while nf_source_has_next(Source)
    [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end
    [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
    if Measure.IsValid
        ValidMeasures(end + 1) = Measure; %#ok<AGROW>
    end
end

%% ===== CHECK DELAY FIELDS =====
% At least one valid Measure should carry the configured delay metadata.
assert(~isempty(ValidMeasures), 'No valid Measures produced.');
Measure = ValidMeasures(1);
assert(Measure.EmpiricalDelaySamples == 37, 'Empirical delay did not propagate.');
assert(Measure.DelayCorrectionUsed == 37, 'DelayCorrectionUsed did not propagate.');
assert(Measure.CorrectedWindowCenterSample == Measure.WindowCenterSample - 37, ...
    'CorrectedWindowCenterSample does not use DelayCorrectionUsed.');

end
