function [Measures, TrialSummary, RTConfig] = nf_run_trial(inputArg)
% NF_RUN_TRIAL Run simulated trial using a finalized baseline.
%
% USAGE:
%     [Measures, TrialSummary, RTConfig] = nf_run_trial(datasetPath)
%     [Measures, TrialSummary, RTConfig] = nf_run_trial(RTConfig)
%
% DESCRIPTION:
%     Loads a trial segment, loads a finalized compatible baseline, replays the
%     segment through the shared real-time core, maps optional debug feedback,
%     and saves a trial log.

%% ===== PARSE INPUTS =====
% Match nf_run_resting and nf_run_validation input conventions.
if nargin < 1 || isempty(inputArg)
    RTConfig = nf_default_config();
elseif isstruct(inputArg)
    RTConfig = inputArg;
elseif ischar(inputArg) || isstring(inputArg)
    RTConfig = nf_default_config();
    RTConfig.Source.DatasetPath = char(inputArg);
else
    error('Input must be empty, an RTConfig struct, or a dataset path string.');
end

RTConfig.Source.Mode = 'simulated_trial';
if isempty(RTConfig.Source.DatasetPath)
    error('Set RTConfig.Source.DatasetPath or call nf_run_trial(datasetPath).');
end
RTConfig = nf_check_config(RTConfig);

%% ===== LOAD DATA AND BASELINE =====
% Infer channel count before loading the baseline so hash comparison can run.
Data = nf_load_validation_data(RTConfig);
if isempty(RTConfig.Spatial.NChannels)
    RTConfig.Spatial.NChannels = size(Data.X, 1);
end
nf_validate_channel_mapping(Data.ChannelNames, RTConfig);
nf_validate_spatial_dimensions(Data, RTConfig);

Baseline = nf_load_baseline(RTConfig);

%% ===== PREPARE SOURCE AND RT =====
% Replay uses local indices because Data is already trimmed by the loader.
SourceConfig = RTConfig;
SourceConfig.Source.StartSample = 1;
SourceConfig.Source.EndSample = size(Data.X, 2);
SourceConfig.Source.Mode = 'simulated_trial';

Source = nf_source_init('simulated_trial', Data, SourceConfig);
RT = nf_rt_prepare(RTConfig, Baseline);

%% ===== RUN TRIAL LOOP =====
% Z-scoring occurs inside nf_rt_process_chunk through the supplied baseline.
estimatedChunks = max(1, ceil(size(Data.X, 2) ./ RTConfig.ChunkSamples));
Measures = repmat(nf_measure_empty(), 1, estimatedChunks);
measureCount = 0;

while nf_source_has_next(Source)
    [chunk, Source] = nf_get_meg_chunk(Source, SourceConfig);
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end

    [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
    if nf_feedback_should_update(Measure, RT, RTConfig)
        Measure = nf_feedback_map_to_display(Measure, RTConfig);
    end

    measureCount = measureCount + 1;
    if measureCount > numel(Measures)
        Measures(measureCount) = nf_measure_empty();
    end
    Measures(measureCount) = Measure;
end
Measures = Measures(1:measureCount);

%% ===== BUILD AND SAVE TRIAL SUMMARY =====
% nf_run_trial owns TrialSummary; the save helper only finalizes path metadata.
TrialSummary = struct();
TrialSummary.NMeasures = numel(Measures);
TrialSummary.NValidMeasures = nnz([Measures.IsValid] == true);
TrialSummary.NFeedbackValues = nnz(isfinite([Measures.FeedbackValue]));
TrialSummary.ConfigHash = RT.ConfigHash;
TrialSummary.ConfigHashInputs = RT.ConfigHashInputs;
TrialSummary.BaselineConfigHash = Baseline.ConfigHash;
TrialSummary.SourceMode = RTConfig.Source.Mode;
TrialSummary.TargetBand = RTConfig.TargetBand;
TrialSummary.Fs = RTConfig.Fs;
TrialSummary.ChunkSamples = RTConfig.ChunkSamples;
TrialSummary.PowerWindowSamples = RTConfig.PowerWindowSamples;
TrialSummary.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

outFile = nf_save_trial_log(Measures, RTConfig, Baseline, TrialSummary);
TrialSummary.OutputFile = outFile;

%% ===== PRINT SUMMARY =====
fprintf('Trial summary\n');
fprintf('  Measures:         %d\n', TrialSummary.NMeasures);
fprintf('  Valid measures:   %d\n', TrialSummary.NValidMeasures);
fprintf('  Feedback values:  %d\n', TrialSummary.NFeedbackValues);
fprintf('  Saved:            %s\n', TrialSummary.OutputFile);

end
