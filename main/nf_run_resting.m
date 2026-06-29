function [Baseline, Measures, RTConfig] = nf_run_resting(inputArg)
% NF_RUN_RESTING Run simulated resting and save a finalized baseline.
%
% USAGE:
%     [Baseline, Measures, RTConfig] = nf_run_resting(datasetPath)
%     [Baseline, Measures, RTConfig] = nf_run_resting(RTConfig)
%
% DESCRIPTION:
%     Replays a simulated resting segment through the shared real-time core,
%     accumulates valid power windows, rejects outliers, finalizes a baseline,
%     checks baseline quality, and saves the finalized baseline.

%% ===== PARSE INPUTS =====
% Match nf_run_validation input conventions where practical.
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

RTConfig.Source.Mode = 'simulated_resting';
if isempty(RTConfig.Source.DatasetPath)
    error('Set RTConfig.Source.DatasetPath or call nf_run_resting(datasetPath).');
end
RTConfig = nf_check_config(RTConfig);

%% ===== LOAD AND VALIDATE DATA =====
% Data loading applies configured source bounds once.
Data = nf_load_validation_data(RTConfig);
if isempty(RTConfig.Spatial.NChannels)
    RTConfig.Spatial.NChannels = size(Data.X, 1);
end
nf_validate_channel_mapping(Data.ChannelNames, RTConfig);
nf_validate_spatial_dimensions(Data, RTConfig);

%% ===== PREPARE SOURCE AND RT =====
% Replay uses local indices because Data is already trimmed by the loader.
SourceConfig = RTConfig;
SourceConfig.Source.StartSample = 1;
SourceConfig.Source.EndSample = size(Data.X, 2);
SourceConfig.Source.Mode = 'simulated_resting';

Source = nf_source_init('simulated_resting', Data, SourceConfig);
RT = nf_rt_prepare(RTConfig);
BaselineAcc = nf_baseline_init(RTConfig, RT);

%% ===== RUN RESTING LOOP =====
% Process each chunk through the same thin core used by validation/trial.
estimatedChunks = max(1, ceil(size(Data.X, 2) ./ RTConfig.ChunkSamples));
Measures = repmat(nf_measure_empty(), 1, estimatedChunks);
measureCount = 0;

while nf_source_has_next(Source)
    [chunk, Source] = nf_get_meg_chunk(Source, SourceConfig);
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end

    [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
    BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig);

    measureCount = measureCount + 1;
    if measureCount > numel(Measures)
        Measures(measureCount) = nf_measure_empty();
    end
    Measures(measureCount) = Measure;
end
Measures = Measures(1:measureCount);

%% ===== FINALIZE BASELINE =====
% Outlier rejection is explicit before final mean/std computation.
BaselineAcc = nf_baseline_reject_outliers(BaselineAcc, RTConfig);
Baseline = nf_baseline_finalize(BaselineAcc, RTConfig);
Quality = nf_baseline_check_quality(Baseline, RTConfig);
Baseline.Quality = Quality;

if ~Quality.Pass
    error('Baseline quality failed: %s', Quality.Message);
end

outFile = nf_save_baseline(Baseline, RTConfig);
Baseline.OutputFile = outFile;

%% ===== PRINT SUMMARY =====
fprintf('Resting baseline summary\n');
fprintf('  Valid windows:    %d\n', Baseline.ValidWindowCount);
fprintf('  Usable windows:   %d\n', Baseline.UsableWindowCount);
fprintf('  Mean/Std:         %.6g / %.6g\n', Baseline.Mean, Baseline.Std);
fprintf('  Quality:          %s\n', Baseline.Quality.Status);
fprintf('  Saved:            %s\n', Baseline.OutputFile);

end
