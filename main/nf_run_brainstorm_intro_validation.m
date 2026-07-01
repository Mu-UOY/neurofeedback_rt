function [Results, Ref, Measures, RTConfig] = nf_run_brainstorm_intro_validation(varargin)
% NF_RUN_BRAINSTORM_INTRO_VALIDATION Validate raw Brainstorm tutorial MEG export.
%
% USAGE:
%     [Results, Ref, Measures, RTConfig] = nf_run_brainstorm_intro_validation()
%     [Results, Ref, Measures, RTConfig] = nf_run_brainstorm_intro_validation( ...
%         'rawDsPath', rawDsPath, 'exportMethod', 'fieldtrip')
%
% DESCRIPTION:
%     Exports or loads the raw Brainstorm Introduction CTF tutorial MEG data,
%     builds the Step 1 validation config, runs nf_run_validation, and prints a
%     concise scientific-validation summary. This runner does not implement
%     live MEG, feedback UI, baseline/trial protocols, inverse modeling, scout
%     mapping, or stimulation communication.

%% ===== RESOLVE DEFAULT PATHS =====
% Defaults match the local tutorial dataset location documented for Step 1B.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
defaultRawDsPath = fullfile('C:\Users\yango\Documents\sample_introduction\data', ...
    'S01_AEF_20131218_01_600Hz.ds');
defaultOutFile = fullfile(projectRoot, 'outputs', 'validation', ...
    'bst_intro_run1_meg_0_120s.mat');

%% ===== PARSE INPUTS =====
% Keep runner options explicit and limited to the raw validation bridge.
p = inputParser();
p.FunctionName = mfilename;
addParameter(p, 'rawDsPath', defaultRawDsPath, @(x) ischar(x) || isstring(x));
addParameter(p, 'outFile', defaultOutFile, @(x) ischar(x) || isstring(x));
addParameter(p, 'timeWindow', [0 120], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'exportMethod', 'auto', @(x) ischar(x) || isstring(x));
addParameter(p, 'targetBand', [8 12], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'channelTarget', 'MEG', @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'brainstormMode', 'skip', @(x) ischar(x) || isstring(x));
addParameter(p, 'requireBrainstormForPass', false, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'brainstormPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'fieldTripPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'brainstormMethod', 'bst-hfilter-2019', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

rawDsPath = char(p.Results.rawDsPath);
outFile = char(p.Results.outFile);
timeWindow = double(p.Results.timeWindow);
exportMethod = char(p.Results.exportMethod);
targetBand = double(p.Results.targetBand);
channelTarget = p.Results.channelTarget;
brainstormMode = char(p.Results.brainstormMode);
requireBrainstormForPass = logical(p.Results.requireBrainstormForPass);
brainstormPath = char(p.Results.brainstormPath);
fieldTripPath = char(p.Results.fieldTripPath);
brainstormMethod = char(p.Results.brainstormMethod);

%% ===== PREPARE OPTIONAL EXTERNAL PATHS =====
% These paths are used only for explicit offline Brainstorm comparison/export.
if ~isempty(brainstormPath)
    addpath(brainstormPath);
end
if ~isempty(fieldTripPath)
    addpath(fieldTripPath);
    if exist('ft_defaults', 'file') ~= 0
        ft_defaults;
    end
end

%% ===== EXPORT OR LOAD DATA =====
% Reuse an existing exported MAT file to avoid unnecessary large raw reads.
if exist(outFile, 'file') ~= 0
    Data = local_load_exported_data(outFile);
    fprintf('Using existing raw validation export: %s\n', outFile);
else
    Data = nf_export_brainstorm_ctf_to_validation_mat(rawDsPath, outFile, ...
        'timeWindow', timeWindow, ...
        'channelTarget', channelTarget, ...
        'exportMethod', exportMethod);
end

Fs = Data.Fs;
nChannels = size(Data.X, 1);
nSamples = size(Data.X, 2);
durationSeconds = nSamples ./ Fs;

%% ===== BUILD VALIDATION CONFIG =====
% The generic validation runner handles offline reference and streaming replay.
RTConfig = nf_brainstorm_intro_validation_config(outFile, Fs, nChannels, targetBand, ...
    'BrainstormMode', brainstormMode, ...
    'RequireBrainstormForPass', requireBrainstormForPass, ...
    'BrainstormPath', brainstormPath, ...
    'FieldTripPath', fieldTripPath, ...
    'BrainstormMethod', brainstormMethod);

%% ===== RUN VALIDATION =====
% This is still simulated-online replay of saved raw MEG, not live acquisition.
[Results, Ref, Measures, RTConfig] = nf_run_validation(RTConfig);

%% ===== PRINT TUTORIAL SUMMARY =====
% Report real sample count from Data.X, not derived reference vector length.
fprintf('\nBrainstorm Introduction validation summary\n');
fprintf('  Exported MAT:   %s\n', outFile);
fprintf('  Export method:  %s\n', local_export_method(Data));
fprintf('  Channels:       %d\n', nChannels);
fprintf('  Samples:        %d\n', nSamples);
fprintf('  Fs:             %.9g Hz\n', Fs);
fprintf('  Duration:       %.3f s\n', durationSeconds);
fprintf('  Target band:    %.3g-%.3g Hz\n', targetBand(1), targetBand(2));
fprintf('  Reference stride: %s, %d samples\n', ...
    Ref.Metadata.ReferenceStrideMode, Ref.Metadata.ReferenceStepSamples);
fprintf('  Reference windows: %d\n', Ref.Metadata.WindowCount);
fprintf('  Step 1 FFT:     %s\n', Results.Step1.FFT.Status);
fprintf('  Step 1 IIR/SOS: %s\n', Results.Step1.IIRSOSComparison.Status);
if isfield(Results.Step1.IIRSOSComparison, 'Message') && ...
        ~isempty(Results.Step1.IIRSOSComparison.Message)
    fprintf('  IIR/SOS note:   %s\n', Results.Step1.IIRSOSComparison.Message);
end
if isfield(Results.Step1.IIRSOSComparison, 'Compare') && ...
        isfield(Results.Step1.IIRSOSComparison.Compare, 'ZCorrelation') && ...
        isfinite(Results.Step1.IIRSOSComparison.Compare.ZCorrelation)
    fprintf('  IIR/SOS vs Brainstorm z-corr: %.6f\n', ...
        Results.Step1.IIRSOSComparison.Compare.ZCorrelation);
end
if isfield(Results.Step1.IIRSOSComparison, 'BrainstormInfo')
    info = Results.Step1.IIRSOSComparison.BrainstormInfo;
    if isfield(info, 'Mode')
        fprintf('  Brainstorm mode: %s\n', info.Mode);
    end
    if isfield(info, 'FunctionName') && ~isempty(info.FunctionName)
        fprintf('  Brainstorm function: %s\n', info.FunctionName);
    end
end
fprintf('  Band detection: %s\n', Results.Step1.BandDetection.Status);
fprintf('  Target power mean/std: %.6g / %.6g\n', ...
    Results.Step1.BandDetection.TargetPowerMean, Results.Step1.BandDetection.TargetPowerStd);
fprintf('  Peak %.3g-%.3g Hz: %.3f Hz\n', ...
    Results.Step1.BandDetection.SearchBand(1), ...
    Results.Step1.BandDetection.SearchBand(2), ...
    Results.Step1.BandDetection.PeakFrequency);
fprintf('  Peak inside target band: %s\n', ...
    local_bool_string(Results.Step1.BandDetection.PeakInsideTargetBand));

if isfield(Results, 'Compare') && isfield(Results.Compare, 'Correlation')
    fprintf('  Compare corr:   %.6f\n', Results.Compare.Correlation);
    fprintf('  Compare RMSE:   %.6g\n', Results.Compare.RMSE);
elseif isfield(Results, 'Compare') && isfield(Results.Compare, 'Status')
    fprintf('  Compare status: %s\n', Results.Compare.Status);
end
if isfield(Results, 'Runtime') && isfield(Results.Runtime, 'Status')
    fprintf('  Runtime status: %s\n', Results.Runtime.Status);
end

fprintf('  Output file:    %s\n', Results.OutputFile);

end

function out = local_bool_string(value)
% Convert logical diagnostics to readable summary text.
if logical(value)
    out = 'true';
else
    out = 'false';
end
end

function Data = local_load_exported_data(matFile)
% Load and validate the canonical raw-export MAT layout.
loaded = load(matFile);

if isfield(loaded, 'Data')
    Data = loaded.Data;
else
    Data = struct();
    requiredFields = {'X','Fs','Time','ChannelNames'};
    for iField = 1:numel(requiredFields)
        if ~isfield(loaded, requiredFields{iField})
            error('Exported MAT missing required field: %s', requiredFields{iField});
        end
    end
    Data.X = loaded.X;
    Data.Fs = loaded.Fs;
    Data.Time = loaded.Time;
    Data.ChannelNames = loaded.ChannelNames;
    if isfield(loaded, 'Events')
        Data.Events = loaded.Events;
    else
        Data.Events = [];
    end
    if isfield(loaded, 'Metadata')
        Data.Metadata = loaded.Metadata;
    else
        Data.Metadata = struct();
    end
end

if ~isfield(Data, 'X') || ~isnumeric(Data.X) || ndims(Data.X) ~= 2 || isempty(Data.X)
    error('Exported Data.X must be a nonempty numeric [channels x samples] matrix.');
end
if ~isfield(Data, 'Fs') || ~isscalar(Data.Fs) || ~isfinite(Data.Fs) || Data.Fs <= 0
    error('Exported Data.Fs must be a finite positive scalar.');
end
if ~isfield(Data, 'Time') || numel(Data.Time) ~= size(Data.X, 2)
    error('Exported Data.Time length must match Data.X samples.');
end
if ~isfield(Data, 'ChannelNames') || numel(Data.ChannelNames) ~= size(Data.X, 1)
    error('Exported Data.ChannelNames length must match Data.X channels.');
end
if ~isfield(Data, 'Events')
    Data.Events = [];
end
if ~isfield(Data, 'Metadata') || isempty(Data.Metadata)
    Data.Metadata = struct();
end
end

function method = local_export_method(Data)
% Summarize provenance when available.
method = 'unknown';
if isfield(Data, 'Metadata') && isfield(Data.Metadata, 'ExportMethod') && ...
        ~isempty(Data.Metadata.ExportMethod)
    method = Data.Metadata.ExportMethod;
end
end
