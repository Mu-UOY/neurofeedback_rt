function Results = nf_run_brainstorm_iir_sos_check(varargin)
% NF_RUN_BRAINSTORM_IIR_SOS_CHECK Run explicit Brainstorm IIR/SOS validation.
%
% USAGE:  Results = nf_run_brainstorm_iir_sos_check()
%
% DESCRIPTION:
%     Local opt-in runner for validating the offline IIR/SOS reference against
%     Brainstorm's direct bandpass function on the Brainstorm Introduction raw
%     CTF tutorial data. This does not touch live MEG or Brainstorm database
%     files directly.

%% ===== PARSE INPUTS =====
% Defaults match the local tutorial installation described for Step 1B.
p = inputParser();
p.FunctionName = mfilename;
addParameter(p, 'rawDsPath', ...
    'C:\Users\yango\Documents\sample_introduction\data\S01_AEF_20131218_01_600Hz.ds', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'brainstormPath', 'C:\Users\yango\Documents\brainstorm3', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'fieldTripPath', 'C:\Users\yango\Documents\fieldtrip', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'targetBand', [8 12], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'timeWindow', [0 120], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'exportMethod', 'fieldtrip', @(x) ischar(x) || isstring(x));
addParameter(p, 'brainstormMode', 'bst_function', @(x) ischar(x) || isstring(x));
addParameter(p, 'requireBrainstormForPass', true, @(x) islogical(x) || isnumeric(x));
parse(p, varargin{:});

rawDsPath = char(p.Results.rawDsPath);
brainstormPath = char(p.Results.brainstormPath);
fieldTripPath = char(p.Results.fieldTripPath);
targetBand = double(p.Results.targetBand);
timeWindow = double(p.Results.timeWindow);
exportMethod = char(p.Results.exportMethod);
brainstormMode = char(p.Results.brainstormMode);
requireBrainstormForPass = logical(p.Results.requireBrainstormForPass);

%% ===== PREPARE EXTERNAL TOOLBOXES =====
% Use Brainstorm and FieldTrip as libraries only; no Brainstorm DB manipulation.
if exist(brainstormPath, 'dir') == 0
    error('Brainstorm path does not exist: %s', brainstormPath);
end
addpath(brainstormPath);
if exist('brainstorm', 'file') == 0
    error('Brainstorm function not found after adding path: %s', brainstormPath);
end
brainstorm nogui;

if exist(fieldTripPath, 'dir') == 0
    error('FieldTrip path does not exist: %s', fieldTripPath);
end
addpath(fieldTripPath);
if exist('ft_defaults', 'file') == 0
    error('ft_defaults not found after adding path: %s', fieldTripPath);
end
ft_defaults;

%% ===== RUN TUTORIAL VALIDATION =====
% The generic runner handles export/reuse and simulated-online validation.
[Results, Ref, Measures, RTConfig] = nf_run_brainstorm_intro_validation( ...
    'rawDsPath', rawDsPath, ...
    'timeWindow', timeWindow, ...
    'exportMethod', exportMethod, ...
    'targetBand', targetBand, ...
    'brainstormMode', brainstormMode, ...
    'requireBrainstormForPass', requireBrainstormForPass, ...
    'brainstormPath', brainstormPath, ...
    'fieldTripPath', fieldTripPath);

%% ===== ASSERT BRAINSTORM COMPARISON PASSED =====
% This runner is explicit: SKIPPED is a failure here.
iirResults = Results.Step1.IIRSOSComparison;
assert(~strcmp(iirResults.Status, 'SKIPPED'), ...
    'Brainstorm IIR/SOS comparison was SKIPPED.');
assert(strcmp(iirResults.Status, 'PASS'), ...
    'Brainstorm IIR/SOS comparison did not PASS: %s', iirResults.Status);
assert(isfield(iirResults, 'Compare') && isfield(iirResults.Compare, 'ZCorrelation') && ...
    isfinite(iirResults.Compare.ZCorrelation), ...
    'Brainstorm IIR/SOS comparison did not produce finite ZCorrelation.');
assert(iirResults.Compare.ZCorrelation >= 0.90, ...
    'Brainstorm IIR/SOS ZCorrelation %.6f is below 0.90.', iirResults.Compare.ZCorrelation);

%% ===== SAVE CHECK OUTPUT =====
% Save a concise, explicit local-check artifact.
outDir = fullfile(RTConfig.Paths.ProjectRoot, 'outputs', 'validation');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outFile = fullfile(outDir, ['brainstorm_iir_sos_check_', stamp, '.mat']);
SavedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')); %#ok<NASGU>
Results.BrainstormIIRSOSCheckOutputFile = outFile;
save(outFile, 'Results', 'Ref', 'Measures', 'RTConfig', 'SavedAt');

%% ===== PRINT SUMMARY =====
% Keep output concise for command-line use.
fprintf('\nBrainstorm IIR/SOS check summary\n');
fprintf('  Status:          %s\n', iirResults.Status);
fprintf('  Z-correlation:   %.6f\n', iirResults.Compare.ZCorrelation);
fprintf('  Brainstorm mode: %s\n', iirResults.BrainstormInfo.Mode);
if isfield(iirResults.BrainstormInfo, 'FunctionName')
    fprintf('  Function:        %s\n', iirResults.BrainstormInfo.FunctionName);
end
fprintf('  Saved:           %s\n', outFile);

end
