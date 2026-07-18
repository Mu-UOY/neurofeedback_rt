function test_marc_validation_report_generation()
% TEST_MARC_VALIDATION_REPORT_GENERATION Check Marc report file generation.

%% ===== CREATE TEMPORARY REPORT ROOT =====
% Report artifacts must not clutter repository output folders.
close(findall(0, 'Type', 'figure'));
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_cleanup(tempRoot)); %#ok<NASGU>

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Analysis.DisplayMode = 'off';
RTConfig.Analysis.ReportRoot = tempRoot;

%% ===== CREATE A TEMPORARY FIGURE PNG =====
% The report generator should copy existing figures into figures/.
fig = figure('Visible', 'off');
plot(1:3, [1 2 3]);
sourceBase = fullfile(tempRoot, 'source_figure');
print(fig, sourceBase, '-dpng', '-r150');
close(fig);
sourcePng = [sourceBase '.png'];

%% ===== BUILD REPORT INPUTS =====
% Include passing theta/wrong-band sections and a simple provided table.
ThetaRecovery = struct();
ThetaRecovery.Pass = true;
ThetaRecovery.Messages = {'theta ok'};
ThetaRecovery.MeanZThetaOn = 1.2;
ThetaRecovery.MeanZThetaOff = 0.1;
ThetaRecovery.ThetaOnMinusThetaOff = 1.1;
ThetaRecovery.PSDPeakFrequency = 6;
ThetaRecovery.PeakInsideTargetBand = true;

WrongBandResult = struct();
WrongBandResult.Pass = true;
WrongBandResult.Messages = {'wrong-band ok'};
WrongBandResult.MeanZWrongBand = 0.2;
WrongBandResult.FalsePositive = false;

ReportInputs = struct();
ReportInputs.ThetaRecovery = ThetaRecovery;
ReportInputs.WrongBandResult = WrongBandResult;
ReportInputs.Tables = struct();
ReportInputs.Tables.ValidationTable = table({'run'}, 0.99, ...
    'VariableNames', {'RunID','Correlation'});
ReportInputs.FigurePaths = {sourcePng};
ReportInputs.RunID = 'report_test';

%% ===== GENERATE REPORT =====
% The report folder should contain summary, README, CSV, and copied PNGs.
Report = nf_make_marc_validation_report(ReportInputs, RTConfig);

assert(exist(Report.ReportDir, 'dir') ~= 0, 'Report directory was not created.');
assert(exist(Report.SummaryPath, 'file') ~= 0, 'summary.mat was not created.');
assert(exist(Report.ReadmePath, 'file') ~= 0, 'README was not created.');
assert(~isempty(Report.TablePaths), 'No CSV paths were returned.');
assert(any(cellfun(@(p) endsWith(p, '.csv') && exist(p, 'file') ~= 0, Report.TablePaths)), ...
    'No CSV file was created.');
assert(~isempty(Report.FigurePaths), 'No copied figure paths were returned.');
assert(all(cellfun(@(p) exist(p, 'file') ~= 0, Report.FigurePaths)), ...
    'Report returned a missing copied figure path.');

readmeText = fileread(Report.ReadmePath);
assert(contains(readmeText, 'Synthetic theta recovery: PASS'), ...
    'README does not contain the theta PASS heading.');
assert(contains(readmeText, 'Wrong-band control: PASS'), ...
    'README does not contain the wrong-band PASS heading.');
assert(contains(readmeText, 'SKIPPED'), ...
    'README should mark unavailable sections as SKIPPED.');
assert(isempty(findall(0, 'Type', 'figure')), ...
    'Report generation left a figure open.');

end

function local_cleanup(tempRoot)
close(findall(0, 'Type', 'figure'));
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
