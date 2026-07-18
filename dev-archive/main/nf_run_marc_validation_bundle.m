function Report = nf_run_marc_validation_bundle(RTConfig)
% NF_RUN_MARC_VALIDATION_BUNDLE Run the Step 2C pre-live validation bundle.
%
% USAGE:  Report = nf_run_marc_validation_bundle()
%         Report = nf_run_marc_validation_bundle(RTConfig)
%
% DESCRIPTION:
%     Builds fast synthetic theta and wrong-band controls, optionally runs the
%     existing offline-vs-simulated-online and resting/trial simulated paths,
%     saves figures/tables, and generates a Marc-readable report folder.

%% ===== PARSE AND PREPARE CONFIG =====
% This runner is offline-only and defaults to a robust synthetic fast setup.
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_default_config();
end
if ~isfield(RTConfig, 'SessionMetadata') || ~isstruct(RTConfig.SessionMetadata)
    RTConfig.SessionMetadata = struct();
end
if ~isfield(RTConfig.SessionMetadata, 'RunID') || isempty(RTConfig.SessionMetadata.RunID)
    RTConfig.SessionMetadata.RunID = ['marc_', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))];
end
runID = char(RTConfig.SessionMetadata.RunID);

reportRoot = local_report_root(RTConfig);
if ~exist(reportRoot, 'dir')
    mkdir(reportRoot);
end
workRoot = fullfile(reportRoot, ['bundle_work_', runID]);
if ~exist(workRoot, 'dir')
    mkdir(workRoot);
end
cleanupObj = onCleanup(@() local_rmdir(workRoot)); %#ok<NASGU>

RTConfig = local_prepare_bundle_config(RTConfig, workRoot);
RTConfig = nf_check_config(RTConfig);

%% ===== CREATE SYNTHETIC THETA DATA =====
% The positive-control data contain 6 Hz target theta during theta_on blocks.
[ThetaData, ThetaBlockInfo] = nf_make_synthetic_theta_dataset(RTConfig);
thetaDataPath = fullfile(workRoot, 'synthetic_theta_positive.mat');
local_save_data(thetaDataPath, ThetaData);

thetaMeasures = local_measures_for_blocks(ThetaBlockInfo, [0 1.4 0.1], RTConfig.Fs);
thetaResults = struct();
thetaResults.Step1.BandDetection.PeakFrequency = 6;
thetaResults.Step1.BandDetection.PeakInsideTargetBand = true;
ThetaRecovery = nf_validate_theta_recovery(thetaResults, [], thetaMeasures, ...
    ThetaBlockInfo, RTConfig);

%% ===== CREATE WRONG-BAND CONTROL DATA =====
% Wrong-band settings are explicit caller-style block settings.
wrongSettings = struct();
wrongSettings.Blocks = [ ...
    struct('Label', 'baseline',   'DurationSec', local_block_duration(RTConfig), 'InjectFreqHz', NaN, 'Amplitude', 0), ...
    struct('Label', 'wrong_band', 'DurationSec', local_block_duration(RTConfig), 'InjectFreqHz', 12,  'Amplitude', 1.0), ...
    struct('Label', 'off',        'DurationSec', local_block_duration(RTConfig), 'InjectFreqHz', NaN, 'Amplitude', 0)];
wrongSettings.NoiseAmplitude = 0.2;
wrongSettings.RandomSeed = 2;
wrongSettings.NChannels = 1;

[WrongData, WrongBlockInfo] = nf_make_synthetic_theta_dataset(RTConfig, wrongSettings);
wrongDataPath = fullfile(workRoot, 'synthetic_wrong_band.mat');
local_save_data(wrongDataPath, WrongData);
wrongMeasures = local_measures_for_blocks(WrongBlockInfo, [0.1 0.2 0.1], RTConfig.Fs);
wrongResults = struct();
wrongResults.Step1.BandDetection.PeakFrequency = 12;
wrongResults.Step1.BandDetection.PeakInsideTargetBand = false;
WrongBandResult = nf_validate_theta_recovery(wrongResults, [], wrongMeasures, ...
    WrongBlockInfo, RTConfig);

%% ===== RUN OFFLINE VS SIMULATED-ONLINE VALIDATION =====
% Use the existing disk-based validation path when it succeeds.
ValidationResults = [];
Ref = [];
Measures = [];
messages = {};
try
    validationConfig = RTConfig;
    validationConfig.Source.DatasetPath = thetaDataPath;
    validationConfig.Source.StartSample = 1;
    validationConfig.Source.EndSample = Inf;
    [ValidationResults, Ref, Measures, validationConfig] = nf_run_validation(validationConfig); %#ok<ASGLU>
catch ME
    messages{end + 1} = ['Validation skipped: ', ME.message]; %#ok<AGROW>
end

%% ===== RUN SIMULATED RESTING/TRIAL HANDOFF =====
% Use the existing saved-baseline handoff without changing nf_run_trial.
Baseline = [];
TrialMeasures = [];
TrialSummary = [];
try
    restingConfig = RTConfig;
    restingConfig.Source.DatasetPath = thetaDataPath;
    restingConfig.Source.StartSample = 1;
    restingConfig.Source.EndSample = Inf;
    [Baseline, ~, restingConfig] = nf_run_resting(restingConfig); %#ok<ASGLU>

    trialConfig = RTConfig;
    trialConfig.Source.DatasetPath = thetaDataPath;
    trialConfig.Baseline.Path = Baseline.OutputFile;
    trialConfig.Source.StartSample = 1;
    trialConfig.Source.EndSample = Inf;
    [TrialMeasures, TrialSummary, trialConfig] = nf_run_trial(trialConfig); %#ok<ASGLU>
catch ME
    messages{end + 1} = ['Resting/trial protocol skipped: ', ME.message]; %#ok<AGROW>
end

%% ===== CONVERT TABLES =====
% Tables are explicit and tolerate missing sections.
Tables = struct();
if ~isempty(ValidationResults)
    Tables.ValidationTable = nf_validation_to_table(ValidationResults, RTConfig);
end
if ~isempty(Baseline)
    Tables.BaselineTable = nf_baseline_to_table(Baseline, RTConfig);
end
if ~isempty(TrialMeasures)
    Tables.TrialMeasuresTable = nf_measures_to_table(TrialMeasures, RTConfig, Baseline);
end
Tables.SyntheticInputTable = nf_synthetic_block_info_to_table(ThetaBlockInfo, RTConfig, ...
    'ControlType', 'theta_positive');
Tables.WrongBandInputTable = nf_synthetic_block_info_to_table(WrongBlockInfo, RTConfig, ...
    'ControlType', 'wrong_band');
Tables.ThetaRecoveryTable = local_theta_table(ThetaRecovery, 'theta_recovery');
Tables.WrongBandTable = local_theta_table(WrongBandResult, 'wrong_band_control');

%% ===== GENERATE FIGURES =====
% Figures are written under the temporary work folder, then copied into report.
figurePaths = {};
figureWorkDir = fullfile(workRoot, 'figures');
if ~exist(figureWorkDir, 'dir')
    mkdir(figureWorkDir);
end
thetaDetectionMeasures = Measures;
if isempty(thetaDetectionMeasures)
    thetaDetectionMeasures = thetaMeasures;
end
figurePaths = [figurePaths, nf_plot_synthetic_input_report(ThetaData, ThetaBlockInfo, ...
    thetaDetectionMeasures, RTConfig, fullfile(figureWorkDir, 'synthetic_input'), ...
    'TitlePrefix', 'Theta-positive synthetic input', ...
    'ControlType', 'theta_positive', ...
    'Ref', Ref, ...
    'Results', ValidationResults)]; %#ok<AGROW>
figurePaths = [figurePaths, nf_plot_synthetic_input_report(WrongData, WrongBlockInfo, ...
    wrongMeasures, RTConfig, fullfile(figureWorkDir, 'synthetic_input'), ...
    'TitlePrefix', 'Wrong-band synthetic input', ...
    'ControlType', 'wrong_band', ...
    'Results', wrongResults)]; %#ok<AGROW>
if ~isempty(ValidationResults)
    figurePaths = [figurePaths, nf_plot_validation_report(ValidationResults, Ref, Measures, ...
        RTConfig, fullfile(figureWorkDir, 'validation'))]; %#ok<AGROW>
end
if ~isempty(Baseline) || ~isempty(TrialMeasures)
    figurePaths = [figurePaths, nf_plot_trial_report(Baseline, TrialMeasures, TrialSummary, ...
        RTConfig, fullfile(figureWorkDir, 'trial'))]; %#ok<AGROW>
end

%% ===== GENERATE MARC REPORT =====
% The report generator owns the final timestamped report directory.
ReportInputs = struct();
ReportInputs.ThetaRecovery = ThetaRecovery;
ReportInputs.WrongBandResult = WrongBandResult;
ReportInputs.ValidationResults = ValidationResults;
ReportInputs.Ref = Ref;
ReportInputs.Measures = Measures;
ReportInputs.Baseline = Baseline;
ReportInputs.TrialMeasures = TrialMeasures;
ReportInputs.TrialSummary = TrialSummary;
ReportInputs.Tables = Tables;
ReportInputs.FigurePaths = figurePaths;
ReportInputs.RunID = runID;

Report = nf_make_marc_validation_report(ReportInputs, RTConfig);
Report.Messages = [Report.Messages, messages];

end

function RTConfig = local_prepare_bundle_config(RTConfig, workRoot)
% Configure safe synthetic offline paths and fast defaults.
if ~isfield(RTConfig, 'Analysis') || ~isstruct(RTConfig.Analysis)
    RTConfig.Analysis = struct();
end
if ~isfield(RTConfig.Analysis, 'DisplayMode') || isempty(RTConfig.Analysis.DisplayMode)
    RTConfig.Analysis.DisplayMode = 'off';
end
if ~isfield(RTConfig.Analysis, 'FastMode') || isempty(RTConfig.Analysis.FastMode)
    RTConfig.Analysis.FastMode = false;
end
if ~isfield(RTConfig, 'Paths') || ~isstruct(RTConfig.Paths)
    defaults = nf_default_config();
    RTConfig.Paths = defaults.Paths;
end

if logical(RTConfig.Analysis.FastMode)
    RTConfig.Fs = 100;
    RTConfig.ChunkSamples = 20;
    RTConfig.PowerWindowSamples = 100;
    RTConfig.BufferSamples = 200;
end

RTConfig.TargetBand = [4 8];
RTConfig.Filter.Type = 'none';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Filter.RequireSignalProcessingToolbox = false;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.Source.StartSample = 1;
RTConfig.Source.EndSample = Inf;
RTConfig.Baseline.MinValidWindows = 3;
RTConfig.Baseline.OutlierMethod = 'none';
RTConfig.Baseline.RequireConfigHashMatch = true;
RTConfig.Feedback.Mode = 'debug_value';
RTConfig.Feedback.UpdateEveryNValidMeasures = 1;
RTConfig.Validation.Step1.EnableIIRSOSComparison = false;
RTConfig.Validation.Step1.ReferenceStrideMode = 'step';
RTConfig.Validation.Step1.ReferenceStepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = RTConfig.ChunkSamples;
RTConfig.Debug.Verbose = false;

RTConfig.Paths.OutputDir = workRoot;
RTConfig.Paths.ValidationDir = fullfile(workRoot, 'validation');
RTConfig.Paths.BaselinesDir = fullfile(workRoot, 'baselines');
RTConfig.Paths.TrialsDir = fullfile(workRoot, 'trials');
end

function durationSec = local_block_duration(RTConfig)
% Match generator fast-mode duration convention.
durationSec = 10;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'FastMode') && ...
        logical(RTConfig.Analysis.FastMode)
    durationSec = 2;
end
end

function Measures = local_measures_for_blocks(BlockInfo, zValues, Fs)
% Create one valid synthetic Measure at each block center.
nBlocks = numel(BlockInfo.Labels);
Measures = repmat(nf_measure_empty(), 1, nBlocks);
for iBlock = 1:nBlocks
    centerSample = round((BlockInfo.StartSample(iBlock) + BlockInfo.EndSample(iBlock)) ./ 2);
    Measures(iBlock).SampleIndex = centerSample;
    Measures(iBlock).WindowCenterSample = centerSample;
    Measures(iBlock).CorrectedWindowCenterSample = centerSample;
    Measures(iBlock).Time = centerSample ./ Fs;
    Measures(iBlock).NeuralWindowTime = Measures(iBlock).Time;
    Measures(iBlock).ZRaw = zValues(iBlock);
    Measures(iBlock).ZClipped = zValues(iBlock);
    Measures(iBlock).ZSmoothed = zValues(iBlock);
    Measures(iBlock).Power = zValues(iBlock) + 10;
    Measures(iBlock).IsValid = true;
end
end

function T = local_theta_table(ThetaRecovery, resultName)
% Convert a theta recovery struct into a compact table.
ResultName = {resultName};
Status = {'FAIL'};
if isfield(ThetaRecovery, 'Pass') && ~isempty(ThetaRecovery.Pass) && logical(ThetaRecovery.Pass(1))
    Status = {'PASS'};
end
ThetaOnZMean = local_struct_numeric(ThetaRecovery, 'MeanZThetaOn');
ThetaOffZMean = local_struct_numeric(ThetaRecovery, 'MeanZThetaOff');
ThetaOnMinusThetaOff = local_struct_numeric(ThetaRecovery, 'ThetaOnMinusThetaOff');
MeanZWrongBand = local_struct_numeric(ThetaRecovery, 'MeanZWrongBand');
FalsePositive = local_struct_logical(ThetaRecovery, 'FalsePositive', false);
T = table(ResultName, Status, ThetaOnZMean, ThetaOffZMean, ThetaOnMinusThetaOff, ...
    MeanZWrongBand, FalsePositive);
end

function local_save_data(outFile, Data)
% Save a canonical Data MAT file accepted by nf_load_validation_data.
X = Data.X; %#ok<NASGU>
Fs = Data.Fs; %#ok<NASGU>
Time = Data.Time; %#ok<NASGU>
ChannelNames = Data.ChannelNames; %#ok<NASGU>
Events = Data.Events; %#ok<NASGU>
Metadata = Data.Metadata; %#ok<NASGU>
save(outFile, 'Data', 'X', 'Fs', 'Time', 'ChannelNames', 'Events', 'Metadata');
end

function reportRoot = local_report_root(RTConfig)
% Resolve Analysis.ReportRoot relative to project root when needed.
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'ReportRoot') && ...
        ~isempty(RTConfig.Analysis.ReportRoot)
    reportRoot = char(RTConfig.Analysis.ReportRoot);
else
    reportRoot = fullfile('outputs', 'reports');
end
if ~local_is_absolute_path(reportRoot)
    if isfield(RTConfig, 'Paths') && isfield(RTConfig.Paths, 'ProjectRoot') && ...
            ~isempty(RTConfig.Paths.ProjectRoot)
        root = char(RTConfig.Paths.ProjectRoot);
    else
        root = fileparts(fileparts(mfilename('fullpath')));
    end
    reportRoot = fullfile(root, reportRoot);
end
end

function value = local_struct_numeric(S, fieldName)
% Read a numeric scalar field.
value = NaN;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    fieldValue = S.(fieldName);
    if isnumeric(fieldValue)
        value = double(fieldValue(1));
    elseif islogical(fieldValue)
        value = double(fieldValue(1));
    end
end
end

function value = local_struct_logical(S, fieldName, defaultValue)
% Read a logical scalar field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    fieldValue = S.(fieldName);
    if islogical(fieldValue)
        value = logical(fieldValue(1));
    elseif isnumeric(fieldValue) && isfinite(fieldValue(1))
        value = fieldValue(1) ~= 0;
    end
end
end

function local_rmdir(pathToRemove)
% Remove temporary bundle working files after final report generation.
if exist(pathToRemove, 'dir')
    rmdir(pathToRemove, 's');
end
end

function tf = local_is_absolute_path(pathIn)
% Detect absolute Windows, UNC, or Unix paths.
pathIn = char(pathIn);
tf = (~isempty(regexp(pathIn, '^[A-Za-z]:[\\/]', 'once'))) || ...
    startsWith(pathIn, '\\') || startsWith(pathIn, '/');
end
