function test_feedback_mapping_separated_from_rt_core()
% TEST_FEEDBACK_MAPPING_SEPARATED_FROM_RT_CORE Check feedback stays outside core.

%% ===== RUN CORE WITH BASELINE =====
% nf_rt_process_chunk should compute z-scores but not assign FeedbackValue.
[Data, RTConfig] = local_synthetic_data_and_config();
Baseline = local_baseline();
Source = nf_source_init('simulated_trial', Data, RTConfig);
RT = nf_rt_prepare(RTConfig, Baseline);

Measure = nf_measure_empty();
while nf_source_has_next(Source)
    [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
    if Measure.IsValid
        break;
    end
end

assert(Measure.IsValid, 'No valid Measure produced.');
assert(isfinite(Measure.ZSmoothed), 'Core did not compute ZSmoothed.');
assert(isnan(Measure.FeedbackValue), 'nf_rt_process_chunk assigned FeedbackValue.');

%% ===== CHECK FEEDBACK UPDATE AND MAPPING =====
% Feedback mapping should be explicit and cadence-controlled.
assert(nf_feedback_should_update(Measure, RT, RTConfig), ...
    'Expected feedback update on every valid Measure for UpdateEveryNValidMeasures=1.');
Mapped = nf_feedback_map_to_display(Measure, RTConfig);
assert(isfinite(Mapped.FeedbackValue), 'debug_value feedback mapping did not produce finite value.');
assert(Mapped.FeedbackValue == Mapped.ZSmoothed, 'FeedbackValue did not map from ZSmoothed.');

RTConfigNone = RTConfig;
RTConfigNone.Feedback.Mode = 'none';
MappedNone = nf_feedback_map_to_display(Measure, RTConfigNone);
assert(isnan(MappedNone.FeedbackValue), 'FeedbackValue should stay NaN when mode is none.');

InvalidMeasure = Measure;
InvalidMeasure.IsValid = false;
assert(~nf_feedback_should_update(InvalidMeasure, RT, RTConfig), ...
    'Invalid Measure should not trigger feedback update.');

end

function [Data, RTConfig] = local_synthetic_data_and_config()
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
RTConfig.Source.Mode = 'simulated_trial';
RTConfig.Fs = Fs;
RTConfig.Filter.Type = 'none';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.TargetBand = [8 12];
RTConfig.ChunkSamples = 20;
RTConfig.PowerWindowSamples = 40;
RTConfig.BufferSamples = 80;
RTConfig.Feedback.Mode = 'debug_value';
RTConfig.Feedback.UpdateEveryNValidMeasures = 1;
RTConfig.Feedback.MapSource = 'ZSmoothed';
end

function Baseline = local_baseline()
Baseline = struct();
Baseline.Type = 'baseline';
Baseline.Partial = false;
Baseline.Finalized = true;
Baseline.Mean = 0.2;
Baseline.Std = 0.1;
Baseline.PowerMean = Baseline.Mean;
Baseline.PowerStd = Baseline.Std;
Baseline.Values = [0.1 0.2 0.3];
Baseline.TrimmedValues = Baseline.Values;
Baseline.ValidWindowCount = 3;
Baseline.UsableWindowCount = 3;
Baseline.InvalidWindowCount = 0;
Baseline.GapWindowCount = 0;
Baseline.ArtifactWindowCount = 0;
Baseline.InvalidReasonCounts = struct();
Baseline.ConfigHash = '';
Baseline.ConfigHashInputs = struct();
Baseline.Metadata = struct();
end
