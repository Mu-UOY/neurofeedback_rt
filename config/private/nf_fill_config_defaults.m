function RTConfig = nf_fill_config_defaults(RTConfig)
% Add Step 1 defaults without overwriting user-provided values.
if ~isfield(RTConfig, 'Validation') || isempty(RTConfig.Validation)
    RTConfig.Validation = struct();
end
if ~isfield(RTConfig, 'Brainstorm') || isempty(RTConfig.Brainstorm)
    RTConfig.Brainstorm = struct();
end
if ~isfield(RTConfig, 'Simulation') || isempty(RTConfig.Simulation)
    RTConfig.Simulation = struct();
end
if ~isfield(RTConfig, 'Baseline') || isempty(RTConfig.Baseline)
    RTConfig.Baseline = struct();
end
if ~isfield(RTConfig, 'Feedback') || isempty(RTConfig.Feedback)
    RTConfig.Feedback = struct();
end
if ~isfield(RTConfig, 'Analysis') || isempty(RTConfig.Analysis)
    RTConfig.Analysis = struct();
end
if ~isfield(RTConfig, 'SessionMetadata') || isempty(RTConfig.SessionMetadata)
    RTConfig.SessionMetadata = struct();
end

RTConfig = local_set_missing(RTConfig, {'Filter','EmpiricalDelaySamples'}, NaN);
RTConfig = local_set_missing(RTConfig, {'Filter','DelayCorrectionUsed'}, NaN);

RTConfig = local_set_missing(RTConfig, {'Simulation','EnableDroppedChunks'}, false);
RTConfig = local_set_missing(RTConfig, {'Simulation','DropProbability'}, 0);
RTConfig = local_set_missing(RTConfig, {'Simulation','DropChunkIndices'}, []);
RTConfig = local_set_missing(RTConfig, {'Simulation','RandomSeed'}, []);
RTConfig = local_set_missing(RTConfig, {'Simulation','EnableJitter'}, false);
RTConfig = local_set_missing(RTConfig, {'Simulation','MaxJitterSamples'}, 0);

RTConfig = local_set_missing(RTConfig, {'Baseline','MinValidWindows'}, 10);
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierMethod'}, 'percentile');
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierPercentileLow'}, 5);
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierPercentileHigh'}, 95);
RTConfig = local_set_missing(RTConfig, {'Baseline','OutlierZThreshold'}, 3);
RTConfig = local_set_missing(RTConfig, {'Baseline','RequireConfigHashMatch'}, true);
RTConfig = local_set_missing(RTConfig, {'Baseline','Path'}, '');

RTConfig = local_set_missing(RTConfig, {'Feedback','Mode'}, 'none');
RTConfig = local_set_missing(RTConfig, {'Feedback','Backend'}, 'none');
RTConfig = local_set_missing(RTConfig, {'Feedback','UpdateEveryNValidMeasures'}, 1);
RTConfig = local_set_missing(RTConfig, {'Feedback','MapSource'}, 'ZSmoothed');
RTConfig = local_set_missing(RTConfig, {'Feedback','ClipRange'}, [-5 5]);
RTConfig = local_set_missing(RTConfig, {'Feedback','LatencyBudgetMs'}, 25);
RTConfig = local_set_missing(RTConfig, {'Feedback','WarnOnLatencyBudgetExceeded'}, true);
RTConfig = local_set_missing(RTConfig, {'Feedback','FailOnLatencyBudgetExceeded'}, false);
RTConfig = local_set_missing(RTConfig, {'Feedback','MaxConsecutiveLatencyWarnings'}, 5);

RTConfig = local_set_missing(RTConfig, {'Analysis','DisplayMode'}, 'off');
RTConfig = local_set_missing(RTConfig, {'Analysis','ReportRoot'}, fullfile('outputs', 'reports'));
RTConfig = local_set_missing(RTConfig, {'Analysis','SaveFigures'}, true);
RTConfig = local_set_missing(RTConfig, {'Analysis','SaveTables'}, true);
RTConfig = local_set_missing(RTConfig, {'Analysis','SaveMat'}, true);
RTConfig = local_set_missing(RTConfig, {'Analysis','FastMode'}, false);
RTConfig = local_set_missing(RTConfig, {'Analysis','MinThetaOnMinusOffZ'}, 0.5);
RTConfig = local_set_missing(RTConfig, {'Analysis','MaxWrongBandMeanZ'}, 1.0);

RTConfig = local_set_missing(RTConfig, {'SessionMetadata','RunID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','DatasetName'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','SubjectID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','SessionID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','TrialID'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','StrategyLabel'}, '');
RTConfig = local_set_missing(RTConfig, {'SessionMetadata','ConditionLabel'}, '');

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','EnableFFTComparison'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','EnableIIRSOSComparison'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','WindowSamples'}, RTConfig.PowerWindowSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','StepSamples'}, RTConfig.ChunkSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','MinCyclesAtLowFreq'}, 3);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','ReferenceStrideMode'}, 'dense');
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','ReferenceStepSamples'}, RTConfig.ChunkSamples);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','SaveDenseDebugReference'}, false);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','UseWelchIfAvailable'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','DemeanBeforeFFT'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','Taper'}, 'hann');
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','NFFT'}, []);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','FFT','ReferenceBands'}, [4 8; 8 12; 13 30]);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','BandDetection','Enable'}, true);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','BandDetection','SearchBand'}, [1 60]);
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','BandDetection','ReferenceBands'}, [4 8; 8 12; 13 30; 30 59]);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','Controls','Enable'}, false);

RTConfig = local_set_missing(RTConfig, {'Validation','Step1','Brainstorm','Mode'}, 'auto');
RTConfig = local_set_missing(RTConfig, {'Validation','Step1','Brainstorm','RequireForPass'}, false);

RTConfig = local_set_missing(RTConfig, {'Brainstorm','Path'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','Version'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','FilterSpecPath'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineFilteredPath'}, '');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineFilteredVariable'}, 'XBrainstorm');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineBandpassFunction'}, 'bst_bandpass_hfilter');
RTConfig = local_set_missing(RTConfig, {'Brainstorm','OfflineBandpassMethod'}, 'bst-hfilter-2019');
end

function S = local_set_missing(S, path, value)
% Set a nested field only when it does not already exist.
if numel(path) == 1
    if ~isfield(S, path{1}) || isempty(S.(path{1}))
        S.(path{1}) = value;
    end
    return;
end

fieldName = path{1};
if ~isfield(S, fieldName) || isempty(S.(fieldName)) || ~isstruct(S.(fieldName))
    S.(fieldName) = struct();
end
S.(fieldName) = local_set_missing(S.(fieldName), path(2:end), value);
end
