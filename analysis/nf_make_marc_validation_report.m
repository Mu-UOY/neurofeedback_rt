function Report = nf_make_marc_validation_report(ReportInputs, RTConfig)
% NF_MAKE_MARC_VALIDATION_REPORT Write a Marc-readable validation report.
%
% USAGE:  Report = nf_make_marc_validation_report(ReportInputs, RTConfig)
%
% DESCRIPTION:
%     Creates a timestamped report folder containing summary MAT/CSV files,
%     available analysis tables, copied figures, and a plain-text validation
%     README generated from actual supplied metrics.

%% ===== PARSE INPUTS =====
% Missing report inputs are accepted and marked SKIPPED where appropriate.
if nargin < 1 || isempty(ReportInputs)
    ReportInputs = struct();
end
if nargin < 2 || isempty(RTConfig)
    RTConfig = nf_default_config();
end
ReportInputs = local_fill_report_inputs(ReportInputs);

%% ===== CREATE REPORT FOLDER =====
% Relative report roots are resolved under the project root when available.
generatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
reportRoot = local_report_root(RTConfig);
if ~exist(reportRoot, 'dir')
    mkdir(reportRoot);
end
reportDir = local_unique_dir(fullfile(reportRoot, ['marc_validation_', stamp]));
mkdir(reportDir);
figureDir = fullfile(reportDir, 'figures');
mkdir(figureDir);

%% ===== COMPUTE SECTION STATUS =====
% Each section is independently PASS/FAIL/SKIPPED.
[thetaStatus, thetaMessage] = local_theta_status(ReportInputs.ThetaRecovery);
[wrongBandStatus, wrongBandMessage] = local_theta_status(ReportInputs.WrongBandResult);
[streamingStatus, streamingMessage] = local_streaming_status(ReportInputs.ValidationResults, RTConfig);
[protocolStatus, protocolMessage] = local_protocol_status(ReportInputs.Baseline, ...
    ReportInputs.TrialMeasures, ReportInputs.TrialSummary);
overallStatus = local_overall_status({thetaStatus, wrongBandStatus, streamingStatus, protocolStatus});

%% ===== COPY FIGURES =====
% Figure paths in the returned Report point to copied files inside reportDir.
[figurePaths, figureMessages] = local_copy_figures(ReportInputs.FigurePaths, figureDir);
[syntheticInputStatus, syntheticInputMessage] = local_synthetic_input_status(ReportInputs, figurePaths);

%% ===== BUILD SUMMARY TABLE =====
% The summary CSV is always a single row with stable columns.
summaryTable = local_summary_table(ReportInputs, generatedAt, overallStatus, ...
    thetaStatus, wrongBandStatus, streamingStatus, protocolStatus);
summaryCsvPath = fullfile(reportDir, 'summary.csv');
writetable(summaryTable, summaryCsvPath);

%% ===== SAVE AVAILABLE TABLES =====
% Tables may be provided directly or generated from supplied structs.
tables = local_available_tables(ReportInputs, RTConfig, summaryTable);
tablePaths = {local_absolute_path(summaryCsvPath)};
tablePaths = local_write_named_tables(tables, reportDir, tablePaths);

%% ===== BUILD REPORT STRUCT =====
% Paths are absolute and output lists include only existing files.
Report = struct();
Report.ReportDir = local_absolute_path(reportDir);
Report.SummaryPath = local_absolute_path(fullfile(reportDir, 'summary.mat'));
Report.ReadmePath = local_absolute_path(fullfile(reportDir, 'README_validation_summary.txt'));
Report.FigurePaths = figurePaths;
Report.TablePaths = tablePaths;
Report.OverallStatus = overallStatus;
Report.SyntheticInputStatus = syntheticInputStatus;
Report.ThetaRecoveryStatus = thetaStatus;
Report.WrongBandStatus = wrongBandStatus;
Report.StreamingAgreementStatus = streamingStatus;
Report.ProtocolStatus = protocolStatus;
Report.Limitations = local_limitations();
Report.Messages = [ ...
    {syntheticInputMessage}, ...
    {thetaMessage}, ...
    {wrongBandMessage}, ...
    {streamingMessage}, ...
    {protocolMessage}, ...
    figureMessages(:)'];

%% ===== SAVE SUMMARY MAT AND README =====
% summary.mat stores the returned Report and concise summary table.
SummaryTable = summaryTable; %#ok<NASGU>
ReportInputsForSave = ReportInputs; %#ok<NASGU>
save(Report.SummaryPath, 'Report', 'SummaryTable', 'ReportInputsForSave');
local_write_readme(Report.ReadmePath, Report, ReportInputs, summaryTable, generatedAt);

end

function ReportInputs = local_fill_report_inputs(ReportInputs)
% Fill optional preferred report input fields.
fields = {'ThetaRecovery','WrongBandResult','ValidationResults','Ref','Measures', ...
    'Baseline','TrialMeasures','TrialSummary','Tables','FigurePaths','RunID'};
defaults = {[], [], [], [], [], [], [], [], struct(), {}, ''};
for iField = 1:numel(fields)
    if ~isfield(ReportInputs, fields{iField})
        ReportInputs.(fields{iField}) = defaults{iField};
    end
end
if isempty(ReportInputs.Tables) || ~isstruct(ReportInputs.Tables)
    ReportInputs.Tables = struct();
end
if isempty(ReportInputs.FigurePaths)
    ReportInputs.FigurePaths = {};
end
end

function reportRoot = local_report_root(RTConfig)
% Resolve Analysis.ReportRoot according to the Step 2C rules.
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
reportRoot = local_absolute_path(reportRoot);
end

function reportDir = local_unique_dir(baseDir)
% Avoid timestamp collisions when tests create multiple reports per second.
reportDir = baseDir;
idx = 1;
while exist(reportDir, 'dir') ~= 0
    reportDir = sprintf('%s_%03d', baseDir, idx);
    idx = idx + 1;
end
end

function [status, message] = local_theta_status(ThetaRecovery)
% Convert theta recovery style structs into PASS/FAIL/SKIPPED.
if isempty(ThetaRecovery) || ~isstruct(ThetaRecovery)
    status = 'SKIPPED';
    message = 'Theta-style result was not provided.';
    return;
end
if isfield(ThetaRecovery, 'Pass') && ~isempty(ThetaRecovery.Pass) && logical(ThetaRecovery.Pass(1))
    status = 'PASS';
else
    status = 'FAIL';
end
message = local_messages_text(ThetaRecovery);
if isempty(message)
    message = sprintf('Theta-style validation status: %s.', status);
end
end

function [status, message] = local_streaming_status(Results, RTConfig)
% Derive offline-vs-streaming status from validation Results.
if isempty(Results) || ~isstruct(Results)
    status = 'SKIPPED';
    message = 'Validation Results were not provided.';
    return;
end
status = local_get_nested_text(Results, {'Compare','Status'}, '');
if isempty(status)
    corrValue = local_get_nested_numeric(Results, {'Compare','Correlation'}, NaN);
    threshold = local_get_nested_numeric(RTConfig, {'Validation','MinAcceptableCorrelation'}, 0.95);
    if isfinite(corrValue)
        if corrValue >= threshold
            status = 'PASS';
        else
            status = 'FAIL';
        end
    else
        status = 'SKIPPED';
    end
end
message = local_get_nested_text(Results, {'Compare','Message'}, '');
if isempty(message)
    corrValue = local_get_nested_numeric(Results, {'Compare','Correlation'}, NaN);
    rmseValue = local_get_nested_numeric(Results, {'Compare','RMSE'}, NaN);
    message = sprintf('Correlation=%s, RMSE=%s.', local_fmt_num(corrValue), local_fmt_num(rmseValue));
end
end

function [status, message] = local_protocol_status(Baseline, TrialMeasures, TrialSummary)
% Derive simulated resting/trial protocol status.
if isempty(Baseline) && isempty(TrialMeasures) && isempty(TrialSummary)
    status = 'SKIPPED';
    message = 'Baseline/trial protocol outputs were not provided.';
    return;
end

baselinePass = false;
if isstruct(Baseline)
    if isfield(Baseline, 'Quality') && isfield(Baseline.Quality, 'Pass') && ~isempty(Baseline.Quality.Pass)
        baselinePass = logical(Baseline.Quality.Pass(1));
    else
        baselinePass = isfield(Baseline, 'Mean') && isfinite(Baseline.Mean) && ...
            isfield(Baseline, 'Std') && isfinite(Baseline.Std) && Baseline.Std > 0;
    end
end
finiteZ = local_finite_z_count(TrialMeasures);
validTrial = local_trial_valid_count(TrialMeasures, TrialSummary);
if baselinePass && finiteZ > 0
    status = 'PASS';
else
    status = 'FAIL';
end
message = sprintf('BaselinePass=%d, validTrial=%d, finiteZ=%d.', ...
    baselinePass, validTrial, finiteZ);
end

function [status, message] = local_synthetic_input_status(ReportInputs, figurePaths)
% Report synthetic-input visibility without affecting algorithm status.
hasTable = local_has_synthetic_input_table(ReportInputs);
hasFigure = any(cellfun(@local_is_input_figure, figurePaths));
if hasTable || hasFigure
    status = 'PASS';
    parts = {};
    if hasTable
        parts{end + 1} = 'synthetic input metadata table provided'; %#ok<AGROW>
    end
    if hasFigure
        parts{end + 1} = 'synthetic input figures provided'; %#ok<AGROW>
    end
    message = strjoin(parts, '; ');
else
    status = 'SKIPPED';
    message = 'Synthetic input metadata/figures were not provided.';
end
end

function tf = local_has_synthetic_input_table(ReportInputs)
% Detect supported synthetic-input metadata table fields.
tf = false;
if ~isfield(ReportInputs, 'Tables') || ~isstruct(ReportInputs.Tables)
    return;
end
fields = {'SyntheticInputTable','WrongBandInputTable','SyntheticInputMetadataTable'};
for iField = 1:numel(fields)
    if isfield(ReportInputs.Tables, fields{iField}) && istable(ReportInputs.Tables.(fields{iField}))
        tf = true;
        return;
    end
end
end

function tf = local_is_input_figure(pathIn)
% Detect copied synthetic-input visibility figures by filename.
[~, name, ext] = fileparts(char(pathIn));
tf = strcmpi(ext, '.png') && contains(lower(name), 'input');
end

function status = local_overall_status(statuses)
% Overall status is conservative: any FAIL makes the bundle FAIL.
if any(strcmp(statuses, 'FAIL'))
    status = 'FAIL';
elseif any(strcmp(statuses, 'PASS'))
    status = 'PASS';
else
    status = 'SKIPPED';
end
end

function [figurePaths, messages] = local_copy_figures(inputPaths, figureDir)
% Copy available PNG files into the report figures folder.
figurePaths = {};
messages = {};
if isempty(inputPaths)
    return;
end
if ischar(inputPaths) || isstring(inputPaths)
    inputPaths = cellstr(inputPaths);
end
for iPath = 1:numel(inputPaths)
    src = char(inputPaths{iPath});
    if isempty(src) || exist(src, 'file') == 0
        messages{end + 1} = sprintf('Figure missing and not copied: %s', src); %#ok<AGROW>
        continue;
    end
    [~, name, ext] = fileparts(src);
    if isempty(ext)
        ext = '.png';
    end
    dst = local_unique_file(fullfile(figureDir, [name ext]));
    try
        copyfile(src, dst);
        if exist(dst, 'file') ~= 0
            figurePaths{end + 1} = local_absolute_path(dst); %#ok<AGROW>
        end
    catch ME
        messages{end + 1} = sprintf('Figure copy failed: %s', ME.message); %#ok<AGROW>
    end
end
end

function outFile = local_unique_file(baseFile)
% Avoid overwriting copied figures with duplicate names.
outFile = baseFile;
idx = 1;
[folder, name, ext] = fileparts(baseFile);
while exist(outFile, 'file') ~= 0
    outFile = fullfile(folder, sprintf('%s_%03d%s', name, idx, ext));
    idx = idx + 1;
end
end

function summaryTable = local_summary_table(ReportInputs, generatedAt, overallStatus, ...
    thetaStatus, wrongBandStatus, streamingStatus, protocolStatus)
% Build the single-row summary table explicitly.
runID = local_report_run_id(ReportInputs);
theta = ReportInputs.ThetaRecovery;
wrong = ReportInputs.WrongBandResult;
validation = ReportInputs.ValidationResults;
baseline = ReportInputs.Baseline;
trialMeasures = ReportInputs.TrialMeasures;
trialSummary = ReportInputs.TrialSummary;

RunID = {runID};
OverallStatus = {overallStatus};
ThetaRecoveryStatus = {thetaStatus};
WrongBandStatus = {wrongBandStatus};
StreamingAgreementStatus = {streamingStatus};
ProtocolStatus = {protocolStatus};
PeakFrequency = local_peak_frequency(validation, theta);
ThetaOnZMean = local_struct_numeric(theta, 'MeanZThetaOn');
ThetaOffZMean = local_struct_numeric(theta, 'MeanZThetaOff');
Correlation = local_get_nested_numeric(validation, {'Compare','Correlation'}, NaN);
RMSE = local_get_nested_numeric(validation, {'Compare','RMSE'}, NaN);
NValidBaseline = local_struct_numeric(baseline, 'ValidWindowCount');
NValidTrial = local_trial_valid_count(trialMeasures, trialSummary);
GeneratedAt = {generatedAt};

summaryTable = table(RunID, OverallStatus, ThetaRecoveryStatus, WrongBandStatus, ...
    StreamingAgreementStatus, ProtocolStatus, PeakFrequency, ThetaOnZMean, ...
    ThetaOffZMean, Correlation, RMSE, NValidBaseline, NValidTrial, GeneratedAt);
end

function tables = local_available_tables(ReportInputs, RTConfig, summaryTable)
% Gather provided tables and generate common missing tables from structs.
tables = ReportInputs.Tables;
tables.SummaryTable = summaryTable;

if ~isfield(tables, 'ValidationTable') && ~isempty(ReportInputs.ValidationResults)
    tables.ValidationTable = nf_validation_to_table(ReportInputs.ValidationResults, RTConfig);
end
if ~isfield(tables, 'BaselineTable') && ~isempty(ReportInputs.Baseline)
    tables.BaselineTable = nf_baseline_to_table(ReportInputs.Baseline, RTConfig);
end
if ~isfield(tables, 'TrialMeasuresTable') && ~isempty(ReportInputs.TrialMeasures)
    tables.TrialMeasuresTable = nf_measures_to_table(ReportInputs.TrialMeasures, RTConfig, ReportInputs.Baseline);
end
if ~isfield(tables, 'ThetaRecoveryTable') && ~isempty(ReportInputs.ThetaRecovery)
    tables.ThetaRecoveryTable = local_theta_table(ReportInputs.ThetaRecovery, 'theta_recovery');
end
if ~isfield(tables, 'WrongBandTable') && ~isempty(ReportInputs.WrongBandResult)
    tables.WrongBandTable = local_theta_table(ReportInputs.WrongBandResult, 'wrong_band_control');
end
end

function tablePaths = local_write_named_tables(tables, reportDir, tablePaths)
% Save available MATLAB tables to fixed CSV names.
mapping = { ...
    'ValidationTable', 'validation_metrics.csv'; ...
    'BaselineTable', 'baseline_summary.csv'; ...
    'TrialMeasuresTable', 'trial_measures.csv'; ...
    'ThetaRecoveryTable', 'theta_recovery.csv'; ...
    'WrongBandTable', 'wrong_band_control.csv'; ...
    'SyntheticInputTable', 'synthetic_input_metadata.csv'; ...
    'SyntheticInputMetadataTable', 'synthetic_input_metadata.csv'; ...
    'WrongBandInputTable', 'wrong_band_input_metadata.csv'};

writtenFiles = {};
for iMap = 1:size(mapping, 1)
    fieldName = mapping{iMap, 1};
    fileName = mapping{iMap, 2};
    if isfield(tables, fieldName) && istable(tables.(fieldName)) && ...
            ~ismember(fileName, writtenFiles)
        outFile = fullfile(reportDir, fileName);
        writetable(tables.(fieldName), outFile);
        if exist(outFile, 'file') ~= 0
            tablePaths{end + 1} = local_absolute_path(outFile); %#ok<AGROW>
            writtenFiles{end + 1} = fileName; %#ok<AGROW>
        end
    end
end
end

function T = local_theta_table(ThetaRecovery, resultName)
% Convert one theta recovery struct into a compact table.
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
PeakFrequency = local_struct_numeric(ThetaRecovery, 'PSDPeakFrequency');
PeakInsideTargetBand = local_struct_logical(ThetaRecovery, 'PeakInsideTargetBand', false);
Message = {local_messages_text(ThetaRecovery)};
T = table(ResultName, Status, ThetaOnZMean, ThetaOffZMean, ThetaOnMinusThetaOff, ...
    MeanZWrongBand, FalsePositive, PeakFrequency, PeakInsideTargetBand, Message);
end

function local_write_readme(readmePath, Report, ReportInputs, summaryTable, generatedAt)
% Write the Marc-readable README using actual metrics/statuses.
fid = fopen(readmePath, 'w');
if fid < 0
    error('Could not create README: %s', readmePath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

theta = ReportInputs.ThetaRecovery;
wrong = ReportInputs.WrongBandResult;
validation = ReportInputs.ValidationResults;
baseline = ReportInputs.Baseline;
trialMeasures = ReportInputs.TrialMeasures;
trialSummary = ReportInputs.TrialSummary;

fprintf(fid, 'Neurofeedback RT Pre-Live Validation Summary\n');
fprintf(fid, 'Generated: %s\n', generatedAt);
fprintf(fid, 'Overall status: %s\n\n', Report.OverallStatus);

fprintf(fid, '0. Synthetic input design: %s\n', Report.SyntheticInputStatus);
fprintf(fid, 'What was provided:\n');
fprintf(fid, 'Synthetic validation data with known injected block timing, injected frequency, and amplitude.\n');
fprintf(fid, 'Key result:\n');
fprintf(fid, 'Input metadata table saved: %s.\n', local_matching_basenames(Report.TablePaths, 'input_metadata'));
fprintf(fid, 'Input figures saved: %s.\n', local_synthetic_input_figure_basenames(Report.FigurePaths));
fprintf(fid, 'Interpretation:\n');
if strcmp(Report.SyntheticInputStatus, 'PASS')
    fprintf(fid, 'The validation output can be checked against the known synthetic input rather than only against algorithm-derived outputs.\n\n');
else
    fprintf(fid, 'SKIPPED: Synthetic input metadata/figures were unavailable for this report.\n\n');
end

fprintf(fid, '1. Synthetic theta recovery: %s\n', Report.ThetaRecoveryStatus);
fprintf(fid, 'What was tested:\n');
fprintf(fid, 'Known target-band theta was injected during theta-on blocks and absent during baseline/off blocks.\n');
fprintf(fid, 'Key result:\n');
fprintf(fid, 'Mean Z during theta-on = %s, mean Z during theta-off = %s, difference = %s.\n', ...
    local_fmt_num(summaryTable.ThetaOnZMean), local_fmt_num(summaryTable.ThetaOffZMean), ...
    local_fmt_num(local_struct_numeric(theta, 'ThetaOnMinusThetaOff')));
fprintf(fid, 'Interpretation:\n');
if strcmp(Report.ThetaRecoveryStatus, 'PASS')
    fprintf(fid, 'The algorithm detects target-band theta when target-band theta is present.\n\n');
elseif strcmp(Report.ThetaRecoveryStatus, 'SKIPPED')
    fprintf(fid, 'SKIPPED: %s\n\n', local_skip_reason(Report.Messages, 2));
else
    fprintf(fid, 'The theta recovery validation did not pass and should be inspected before live testing.\n\n');
end

fprintf(fid, '2. Wrong-band control: %s\n', Report.WrongBandStatus);
fprintf(fid, 'What was tested:\n');
fprintf(fid, 'A non-target frequency was injected while the target band remained unchanged.\n');
fprintf(fid, 'Key result:\n');
fprintf(fid, 'Mean target-band Z during wrong-band block = %s, false-positive status = %s.\n', ...
    local_fmt_num(local_struct_numeric(wrong, 'MeanZWrongBand')), ...
    local_bool_text(local_struct_logical(wrong, 'FalsePositive', false)));
fprintf(fid, 'Interpretation:\n');
if strcmp(Report.WrongBandStatus, 'PASS')
    fprintf(fid, 'The algorithm does not falsely classify wrong-band activity as target theta.\n\n');
elseif strcmp(Report.WrongBandStatus, 'SKIPPED')
    fprintf(fid, 'SKIPPED: %s\n\n', local_skip_reason(Report.Messages, 3));
else
    fprintf(fid, 'The wrong-band control suggests possible false-positive behavior.\n\n');
end

fprintf(fid, '3. Offline vs simulated-online agreement: %s\n', Report.StreamingAgreementStatus);
fprintf(fid, 'What was tested:\n');
fprintf(fid, 'The same dataset was processed as a full offline reference and as simulated-online chunks.\n');
fprintf(fid, 'Key result:\n');
fprintf(fid, 'Correlation = %s, RMSE = %s, empirical delay = %s samples.\n', ...
    local_fmt_num(summaryTable.Correlation), local_fmt_num(summaryTable.RMSE), ...
    local_fmt_num(local_get_nested_numeric(validation, {'Delay','EmpiricalDelaySamples'}, NaN)));
fprintf(fid, 'Interpretation:\n');
if strcmp(Report.StreamingAgreementStatus, 'PASS')
    fprintf(fid, 'Chunking/filter state/buffer logic reproduce the offline reference.\n\n');
elseif strcmp(Report.StreamingAgreementStatus, 'SKIPPED')
    fprintf(fid, 'SKIPPED: %s\n\n', local_skip_reason(Report.Messages, 4));
else
    fprintf(fid, 'The streaming implementation should be inspected before live testing.\n\n');
end

fprintf(fid, '4. Simulated resting/trial protocol: %s\n', Report.ProtocolStatus);
fprintf(fid, 'What was tested:\n');
fprintf(fid, 'A simulated resting baseline was saved and reloaded for a simulated trial.\n');
fprintf(fid, 'Key result:\n');
fprintf(fid, 'Valid baseline windows = %s, valid trial measures = %s, finite z-score count = %s.\n', ...
    local_fmt_num(local_struct_numeric(baseline, 'ValidWindowCount')), ...
    local_fmt_num(local_trial_valid_count(trialMeasures, trialSummary)), ...
    local_fmt_num(local_finite_z_count(trialMeasures)));
fprintf(fid, 'Interpretation:\n');
if strcmp(Report.ProtocolStatus, 'PASS')
    fprintf(fid, 'The baseline -> trial -> z-score protocol is inspectable and ready for live dry-run preparation.\n\n');
elseif strcmp(Report.ProtocolStatus, 'SKIPPED')
    fprintf(fid, 'SKIPPED: %s\n\n', local_skip_reason(Report.Messages, 5));
else
    fprintf(fid, 'The simulated protocol should be fixed before live testing.\n\n');
end

fprintf(fid, 'Limitations:\n');
fprintf(fid, '%s\n', Report.Limitations);
end

function textOut = local_messages_text(S)
% Collapse Messages fields to a printable string.
textOut = '';
if ~isstruct(S) || ~isfield(S, 'Messages') || isempty(S.Messages)
    return;
end
messages = S.Messages;
if ischar(messages) || isstring(messages)
    textOut = char(messages);
elseif iscell(messages)
    parts = cell(1, numel(messages));
    for i = 1:numel(messages)
        parts{i} = char(messages{i});
    end
    textOut = strjoin(parts, ' ');
end
end

function value = local_report_run_id(ReportInputs)
% Prefer explicit report RunID.
value = '';
if isfield(ReportInputs, 'RunID') && ~isempty(ReportInputs.RunID)
    value = char(ReportInputs.RunID);
end
end

function value = local_peak_frequency(validation, theta)
% Read peak frequency from validation results or theta recovery.
value = local_get_nested_numeric(validation, {'Step1','BandDetection','PeakFrequency'}, NaN);
if ~isfinite(value)
    value = local_get_nested_numeric(validation, {'Band','PeakFrequency'}, NaN);
end
if ~isfinite(value)
    value = local_struct_numeric(theta, 'PSDPeakFrequency');
end
end

function value = local_trial_valid_count(trialMeasures, trialSummary)
% Count valid trial measures from summary or measure flags.
value = local_struct_numeric(trialSummary, 'NValidMeasures');
if isfinite(value)
    return;
end
if isstruct(trialMeasures) && ~isempty(trialMeasures) && isfield(trialMeasures, 'IsValid')
    isValid = false(1, numel(trialMeasures));
    for i = 1:numel(trialMeasures)
        isValid(i) = ~isempty(trialMeasures(i).IsValid) && logical(trialMeasures(i).IsValid(1));
    end
    value = nnz(isValid);
else
    value = NaN;
end
end

function n = local_finite_z_count(trialMeasures)
% Count finite z-score values in trial measures.
n = 0;
if ~isstruct(trialMeasures) || isempty(trialMeasures)
    return;
end
for i = 1:numel(trialMeasures)
    if isfield(trialMeasures, 'ZSmoothed') && isfinite(trialMeasures(i).ZSmoothed)
        n = n + 1;
    elseif isfield(trialMeasures, 'ZClipped') && isfinite(trialMeasures(i).ZClipped)
        n = n + 1;
    elseif isfield(trialMeasures, 'ZRaw') && isfinite(trialMeasures(i).ZRaw)
        n = n + 1;
    end
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

function value = local_get_nested_numeric(S, path, defaultValue)
% Read a nested numeric scalar with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if isnumeric(current) && ~isempty(current)
    value = double(current(1));
elseif islogical(current) && ~isempty(current)
    value = double(current(1));
end
end

function value = local_get_nested_text(S, path, defaultValue)
% Read a nested text field with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if isempty(current)
    return;
elseif ischar(current) || isstring(current)
    value = char(current);
elseif isnumeric(current) || islogical(current)
    value = num2str(current(1));
end
end

function textOut = local_fmt_num(value)
% Format numeric values for README text.
if isnumeric(value) && ~isempty(value) && isfinite(value(1))
    textOut = sprintf('%.6g', value(1));
else
    textOut = 'NaN';
end
end

function textOut = local_bool_text(value)
% Format logical values for README text.
if logical(value)
    textOut = 'true';
else
    textOut = 'false';
end
end

function textOut = local_matching_basenames(paths, pattern)
% Return comma-separated basenames whose filenames contain a pattern.
matches = {};
if isempty(paths)
    textOut = 'none';
    return;
end
for iPath = 1:numel(paths)
    [~, name, ext] = fileparts(char(paths{iPath}));
    fileName = [name ext];
    if contains(lower(fileName), lower(pattern))
        matches{end + 1} = fileName; %#ok<AGROW>
    end
end
if isempty(matches)
    textOut = 'none';
else
    textOut = strjoin(matches, ', ');
end
end

function textOut = local_synthetic_input_figure_basenames(paths)
% Return synthetic-input visibility figure basenames for README reporting.
patterns = {'input','raw_signal','injection_vs_detected','input_vs_target'};
matches = {};
if isempty(paths)
    textOut = 'none';
    return;
end
for iPath = 1:numel(paths)
    [~, name, ext] = fileparts(char(paths{iPath}));
    fileName = [name ext];
    lowerName = lower(fileName);
    for iPattern = 1:numel(patterns)
        if contains(lowerName, patterns{iPattern})
            matches{end + 1} = fileName; %#ok<AGROW>
            break;
        end
    end
end
if isempty(matches)
    textOut = 'none';
else
    textOut = strjoin(matches, ', ');
end
end

function reason = local_skip_reason(messages, idx)
% Return a section message by index when available.
reason = 'Section inputs were unavailable.';
if numel(messages) >= idx && ~isempty(messages{idx})
    reason = messages{idx};
end
end

function textOut = local_limitations()
% Standard current-scope limitation text.
textOut = ['This does not prove live MEG acquisition, live channel mapping, ', ...
    'real IPS source projection, final feedback UI, trigger synchronization, ', ...
    'or participant self-regulation.'];
end

function outPath = local_absolute_path(pathIn)
% Convert a path to an absolute path without requiring Java.
pathIn = char(pathIn);
if local_is_absolute_path(pathIn)
    outPath = pathIn;
else
    outPath = fullfile(pwd, pathIn);
end
end

function tf = local_is_absolute_path(pathIn)
% Detect absolute Windows, UNC, or Unix paths.
pathIn = char(pathIn);
tf = (~isempty(regexp(pathIn, '^[A-Za-z]:[\\/]', 'once'))) || ...
    startsWith(pathIn, '\\') || startsWith(pathIn, '/');
end
