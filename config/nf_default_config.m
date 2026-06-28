function RTConfig = nf_default_config()
% NF_DEFAULT_CONFIG Return the default neurofeedback processing config.
%
% USAGE:  RTConfig = nf_default_config()
%
% DESCRIPTION:
%     Builds a first-version RTConfig with conservative defaults for offline
%     validation, simulated-online replay, filtering, buffering, paths, and
%     validation thresholds.

%% ===== RESOLVE PROJECT ROOT =====
% The config folder is one level under the neurofeedback_rt project root.
projectRoot = fileparts(fileparts(mfilename('fullpath')));

%% ===== INITIALIZE CONFIG STRUCT =====
% Top-level values describe sample timing, window sizes, and target band.
RTConfig = struct();

RTConfig.Fs = 1200;
RTConfig.ChunkSamples = 120;
RTConfig.PowerWindowSamples = 600;
RTConfig.BufferSamples = 2400;
RTConfig.TargetBand = [4 8];

%% ===== FILTER DEFAULTS =====
% iir_sos is the default first-version streaming filter implementation.
RTConfig.Filter.Type = 'iir_sos';
RTConfig.Filter.Order = 4;
RTConfig.Filter.AnalyticGroupDelaySamples = NaN;
RTConfig.Filter.EmpiricalDelaySamples = NaN;
RTConfig.Filter.DelayCorrectionUsed = NaN;
RTConfig.Filter.DiscardInitialSamples = [];
RTConfig.Filter.IIRDesignMethod = 'butter_sos';
RTConfig.Filter.RequireSignalProcessingToolbox = true;

%% ===== SOURCE DEFAULTS =====
% Simulated-online mode replays a saved dataset chunk by chunk.
RTConfig.Source.Mode = 'simulated_online';
RTConfig.Source.DatasetPath = '';
RTConfig.Source.StartSample = 1;
RTConfig.Source.EndSample = Inf;

%% ===== SIMULATION DEFAULTS =====
% Dropped-chunk and jitter simulation are disabled by default.
RTConfig.Simulation.EnableDroppedChunks = false;
RTConfig.Simulation.DropProbability = 0;
RTConfig.Simulation.EnableJitter = false;
RTConfig.Simulation.MaxJitterSamples = 0;

%% ===== SPATIAL DEFAULTS =====
% Identity projection keeps all channels unless the user overrides it.
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = [];
RTConfig.Spatial.TargetChannelIndex = 1;
RTConfig.Spatial.ExpectedChannelNames = {};
RTConfig.Spatial.CombinedMatrix = [];

%% ===== Z-SCORE DEFAULTS =====
% Feedback normalization is clipped and smoothed when a baseline is present.
RTConfig.ZScore.ClipRange = [-5 5];
RTConfig.ZScore.SmoothAlpha = 0.8;

%% ===== DEBUG DEFAULTS =====
% Schema checks favor early failures during first-version development.
RTConfig.Debug.CheckMeasureSchema = true;
RTConfig.Debug.CheckRTSchema = true;
RTConfig.Debug.Verbose = true;

%% ===== PATH DEFAULTS =====
% Keep output paths under the project root.
RTConfig.Paths.ProjectRoot = projectRoot;
RTConfig.Paths.OutputDir = fullfile(projectRoot, 'outputs');
RTConfig.Paths.ValidationDir = fullfile(projectRoot, 'outputs', 'validation');
RTConfig.Paths.BaselinesDir = fullfile(projectRoot, 'outputs', 'baselines');
RTConfig.Paths.TrialsDir = fullfile(projectRoot, 'outputs', 'trials');

%% ===== BRAINSTORM DEFAULTS =====
% Runtime brainstorm_fir mode currently requires a saved FilterSpecPath.
RTConfig.Brainstorm.Path = '';
RTConfig.Brainstorm.Version = '';
RTConfig.Brainstorm.FilterSpecPath = '';
RTConfig.Brainstorm.OfflineFilteredPath = '';
RTConfig.Brainstorm.OfflineFilteredVariable = 'XBrainstorm';
RTConfig.Brainstorm.OfflineBandpassFunction = 'bst_bandpass_hfilter';

%% ===== SYNC DEFAULTS =====
% Zero tolerance requires exact sample-index continuity.
RTConfig.Sync.SampleIndexTolerance = 0;

%% ===== VALIDATION DEFAULTS =====
% Thresholds control offline-reference versus streaming comparisons.
RTConfig.Validation.MaxLagSamples = 2 * RTConfig.Fs;
RTConfig.Validation.MinAcceptableCorrelation = 0.95;
RTConfig.Validation.ExcellentCorrelation = 0.99;
RTConfig.Validation.MaxRuntimeFraction = 0.8;
RTConfig.Validation.AlignmentSampleField = 'WindowCenterSample';
RTConfig.Validation.UseCorrectedSamplesForDirectComparison = false;

%% ===== STEP 1 OFFLINE SCIENTIFIC VALIDATION DEFAULTS =====
% Step 1 adds spectral and offline filter-comparison sanity checks.
RTConfig.Validation.Step1.EnableFFTComparison = true;
RTConfig.Validation.Step1.EnableIIRSOSComparison = true;
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.MinCyclesAtLowFreq = 3;

RTConfig.Validation.Step1.FFT.UseWelchIfAvailable = true;
RTConfig.Validation.Step1.FFT.DemeanBeforeFFT = true;
RTConfig.Validation.Step1.FFT.Taper = 'hann';
RTConfig.Validation.Step1.FFT.NFFT = [];
RTConfig.Validation.Step1.FFT.ReferenceBands = [
    4 8
    8 12
    13 30
];

RTConfig.Validation.Step1.Brainstorm.Mode = 'auto';
RTConfig.Validation.Step1.Brainstorm.RequireForPass = false;

%% ===== HASH DEFAULTS =====
% The hash is a deterministic debugging fingerprint, not a security feature.
RTConfig.Hash.Method = 'simple_sorted_fields';
RTConfig.Hash.KnownLimitation = ...
    'First-version hash is a deterministic debugging fingerprint, not a cryptographic identity.';

end
