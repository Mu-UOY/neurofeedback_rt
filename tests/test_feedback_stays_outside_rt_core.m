function test_feedback_stays_outside_rt_core()
% TEST_FEEDBACK_STAYS_OUTSIDE_RT_CORE Check local-circle mapping stays external.

%% ===== RUN CORE WITHOUT FEEDBACK MAPPING =====
% nf_rt_process_chunk should compute z-scores but leave feedback fields unset.
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
assert(isnan(Measure.FeedbackValue), 'RT core assigned FeedbackValue.');
assert(isnan(Measure.FeedbackTargetRadiusPx), ...
    'RT core assigned FeedbackTargetRadiusPx.');
assert(isnan(Measure.FeedbackDisplayRadiusPx), ...
    'RT core assigned FeedbackDisplayRadiusPx.');
assert(isnan(Measure.FeedbackOuterRadiusPx), ...
    'RT core assigned FeedbackOuterRadiusPx.');

%% ===== MAP FEEDBACK EXPLICITLY OUTSIDE CORE =====
% Feedback mapping is a separate post-core step.
Mapped = nf_feedback_map_to_display(Measure, RTConfig);
assert(isfinite(Mapped.FeedbackValue), ...
    'Explicit local-circle mapping did not assign FeedbackValue.');
assert(isfinite(Mapped.FeedbackTargetRadiusPx), ...
    'Explicit local-circle mapping did not assign target radius.');
assert(isfinite(Mapped.FeedbackDisplayRadiusPx), ...
    'Explicit local-circle mapping did not assign display radius.');
assert(isfinite(Mapped.FeedbackOuterRadiusPx), ...
    'Explicit local-circle mapping did not assign outer radius.');
assert(strcmp(Mapped.FeedbackDisplayType, 'circle'), ...
    'Explicit local-circle mapping did not assign circle display type.');

%% ===== SCAN RT CORE FOR FEEDBACK MAPPING =====
% Strip MATLAB comments so comments alone cannot trigger the guard.
rtCorePath = fullfile(nf_project_root(), 'rt', 'nf_rt_process_chunk.m');
sourceText = fileread(rtCorePath);
sourceText = regexprep(sourceText, '%[^\n\r]*', '');

blockedTokens = { ...
    'FeedbackTargetRadiusPx', ...
    'FeedbackDisplayRadiusPx', ...
    'FeedbackOuterRadiusPx', ...
    'nf_feedback_map_to_display', ...
    'nf_feedback_circle_radius'};
for iToken = 1:numel(blockedTokens)
    assert(~contains(sourceText, blockedTokens{iToken}), ...
        'Feedback mapping token found in RT core: %s', blockedTokens{iToken});
end

end

function [Data, RTConfig] = local_synthetic_data_and_config()
% Build a small simulated trial with local-circle feedback configured.
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

Modes = nf_modes();
LiveConfig = nf_live_config();
RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.UpdateEveryNValidMeasures = 1;
RTConfig.Feedback.MapSource = 'ZSmoothed';
RTConfig.Feedback.Circle = LiveConfig.Feedback.Circle;
end

function Baseline = local_baseline()
% Create a finalized baseline that yields finite z-scores.
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
