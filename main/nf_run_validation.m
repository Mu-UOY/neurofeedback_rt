function [Results, Ref, Measures, RTConfig] = nf_run_validation(inputArg)
% NF_RUN_VALIDATION Run offline reference + simulated-online validation.
%
% USAGE:
%     Results = nf_run_validation(datasetPath)
%     Results = nf_run_validation(RTConfig)
%
% DESCRIPTION:
%     Loads a recorded dataset, computes a causal offline reference, replays
%     the same data in simulated-online chunks, processes each chunk through
%     the real-time pipeline, then compares streaming output to the offline
%     reference.

%% ===== PARSE INPUTS =====
% nargin is a MATLAB built-in: number of input arguments actually provided.
% If no input is provided, use the default config.
if nargin < 1 || isempty(inputArg)
    RTConfig = nf_default_config();

% If the input is already a config struct, use it directly.
elseif isstruct(inputArg)
    RTConfig = inputArg;

% Otherwise, assume the input is a dataset path.
elseif ischar(inputArg) || isstring(inputArg)
    RTConfig = nf_default_config();
    RTConfig.Source.DatasetPath = char(inputArg);

% Throw an error if input is not empty, an RTConfig struct, or a dataset path string.
else
    error('Input must be empty, an RTConfig struct, or a dataset path string.')
end

% A validation run needs a saved dataset path.
if isempty(RTConfig.Source.DatasetPath)
    error('Set RTConfig.Source.DatasetPath or call nf_run_validation(datasetPath).');
end


%% ===== CHECK CONFIGURATION =====
% Force this entry point to use simulated-online replay, not live MEG.
RTConfig.Source.Mode = 'simulated_online';

% Validate required fields, filter settings, source mode, paths, etc.
RTConfig = nf_check_config(RTConfig);


%% ===== LOAD DATASET =====
% Load recorded data into canonical Data format:
%     Data.X              [channels x samples]
%     Data.Fs             sampling rate
%     Data.Time           sample times
%     Data.ChannelNames   channel labels
%     Data.Events         optional events
Data = nf_load_validation_data(RTConfig);

% If channel count was not set manually, infer it from the dataset.
if isempty(RTConfig.Spatial.NChannels)
    RTConfig.Spatial.NChannels = size(Data.X, 1);
end

% Check channel labels/order and spatial dimensions before processing.
nf_validate_channel_mapping(Data.ChannelNames, RTConfig);
nf_validate_spatial_dimensions(Data, RTConfig);

%% ===== PREPARE REPLAY CONFIG =====
% Data is already trimmed by nf_load_validation_data. Source replay must use
% local indices so RTConfig.Source.StartSample/EndSample are not applied twice.
SourceConfig = RTConfig;
SourceConfig.Source.StartSample = 1;
SourceConfig.Source.EndSample = size(Data.X, 2);
SourceConfig.Source.Mode = 'simulated_online';


%% ===== BUILD OFFLINE REFERENCE =====
% Compute the causal full-data reference.
% This is the offline result that simulated-online streaming should match.
Ref = nf_make_offline_reference(Data, RTConfig);


%% ===== RUN STEP 1 OFFLINE SCIENTIFIC VALIDATION =====
% Step 1 asks whether the offline spectral/filter methods are sensible.
Step1Results = struct();

if isfield(RTConfig.Validation, 'Step1') && RTConfig.Validation.Step1.EnableFFTComparison
    Step1Results.FFT = nf_validate_fft_comparison(Data, Ref, RTConfig);
else
    Step1Results.FFT.Status = 'SKIPPED';
    Step1Results.FFT.Message = 'FFT comparison disabled.';
end

if isfield(RTConfig.Validation, 'Step1') && RTConfig.Validation.Step1.EnableIIRSOSComparison
    Step1Results.IIRSOSComparison = nf_validate_iir_sos_comparison(Data, Ref, RTConfig);
else
    Step1Results.IIRSOSComparison.Status = 'SKIPPED';
    Step1Results.IIRSOSComparison.Message = 'IIR/SOS comparison disabled.';
end


%% ===== INITIALIZE SIMULATED ONLINE SOURCE =====
% Create a source adapter that replays the recorded dataset chunk by chunk.
Source = nf_source_init('simulated_online', Data, SourceConfig);


%% ===== INITIALIZE REAL-TIME STATE =====
% Prepare mutable runtime state:
%     spatial matrix
%     filter state
%     circular buffer
%     counters
%     timing logs
%     config hash
RT = nf_rt_prepare(RTConfig);


%% ===== PREALLOCATE MEASURE OUTPUT =====
% Estimate the number of chunks for efficient preallocation.
nSamples = Source.EndSample - Source.StartSample + 1;
estimatedChunks = max(1, ceil(nSamples ./ RTConfig.ChunkSamples));

% One Measure is produced per processed chunk.
Measures = repmat(nf_measure_empty(), 1, estimatedChunks);
measureCount = 0;


%% ===== SIMULATED REAL-TIME LOOP =====
% Replay recorded data in chunks and process each chunk through the same
% function that will later be used for live data.
while nf_source_has_next(Source)

    % Get next simulated MEG chunk.
    [chunk, Source] = nf_get_meg_chunk(Source, SourceConfig);

    % Skip empty chunks, if any.
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end

    % Core real-time processing:
    %     check chunk
    %     apply spatial projection
    %     filter
    %     append to buffer
    %     extract sliding window
    %     compute power
    %     package Measure
    [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);

    % Store Measure.
    measureCount = measureCount + 1;

    % Defensive expansion if the estimated number of chunks was too small.
    if measureCount > numel(Measures)
        Measures(measureCount) = nf_measure_empty();
    end

    Measures(measureCount) = Measure;
end

% Remove unused preallocated Measure slots.
Measures = Measures(1:measureCount);


%% ===== VALIDATE STREAMING AGAINST OFFLINE REFERENCE =====
% Estimate empirical delay between reference and stream.
DelayResults = nf_validate_empirical_filter_delay(Ref, Measures, RTConfig);

% Compare offline reference power against simulated-online streaming power.
CompareResults = nf_validate_brainstorm_vs_streaming(Ref, Measures, RTConfig);

% Summarize whether target-band power was produced.
BandResults = nf_validate_band_detection(Data, Ref, Measures, RTConfig, Step1Results.FFT);
Step1Results.BandDetection = BandResults;

% Check whether processing time is compatible with real-time use.
RuntimeResults = nf_validate_filter_runtime(RT.Timing.ChunkProcessingTimes, RTConfig);


%% ===== PACKAGE RESULTS =====
Results = struct();

Results.Delay = DelayResults;
Results.Compare = CompareResults;
Results.Band = BandResults;
Results.Runtime = RuntimeResults;
Results.Step1 = Step1Results;

Results.NChunks = measureCount;
Results.NValidMeasures = nnz([Measures.IsValid] == true);
Results.ConfigHash = RT.ConfigHash;


%% ===== SAVE RESULTS =====
% Save Ref, Measures, Results, and RTConfig to outputs/validation.
Results.OutputFile = nf_save_validation_results(Ref, Measures, Results, RTConfig);


%% ===== PRINT SUMMARY =====
fprintf('Validation summary\n');
fprintf('  Chunks processed: %d\n', Results.NChunks);
fprintf('  Valid measures:   %d\n', Results.NValidMeasures);

if isfield(CompareResults, 'Correlation')
    fprintf('  Correlation:      %.6f\n', CompareResults.Correlation);
    fprintf('  RMSE:             %.6g\n', CompareResults.RMSE);
else
    fprintf('  Comparison:       %s\n', CompareResults.Status);
end

fprintf('  Runtime status:   %s\n', RuntimeResults.Status);
fprintf('  Step 1 FFT:       %s\n', Results.Step1.FFT.Status);
fprintf('  Step 1 IIR/SOS:   %s\n', Results.Step1.IIRSOSComparison.Status);
fprintf('  Band detection:   %s\n', Results.Step1.BandDetection.Status);
if isfield(Results.Step1.IIRSOSComparison, 'Compare') && ...
        isfield(Results.Step1.IIRSOSComparison.Compare, 'ZCorrelation') && ...
        isfinite(Results.Step1.IIRSOSComparison.Compare.ZCorrelation)
    fprintf('  IIR/SOS z-corr:   %.6f\n', Results.Step1.IIRSOSComparison.Compare.ZCorrelation);
elseif isfield(Results.Step1.IIRSOSComparison, 'Message') && ...
        ~isempty(Results.Step1.IIRSOSComparison.Message)
    fprintf('  IIR/SOS note:     %s\n', Results.Step1.IIRSOSComparison.Message);
end
fprintf('  Saved:            %s\n', Results.OutputFile);

end
