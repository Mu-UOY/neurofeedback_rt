function test_marc_report_includes_synthetic_input_metadata()
% TEST_MARC_REPORT_INCLUDES_SYNTHETIC_INPUT_METADATA Check metadata CSV output.

%% ===== CREATE TEMPORARY REPORT ROOT =====
% Report artifacts should stay under a temp folder.
close(findall(0, 'Type', 'figure'));
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_cleanup(tempRoot)); %#ok<NASGU>

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Analysis.DisplayMode = 'off';
RTConfig.Analysis.ReportRoot = tempRoot;

%% ===== BUILD MINIMAL REPORT INPUTS =====
% A synthetic input table alone should create the metadata CSV and README section.
SyntheticInputTable = table({'run_001'}, {'synthetic'}, {'theta_positive'}, 1, ...
    {'theta_on'}, 1, 100, 0, 1, 1, 6, 1, 4, 8, true, false, ...
    'VariableNames', {'RunID','DatasetName','ControlType','BlockIndex','BlockLabel', ...
    'StartSample','EndSample','StartTimeSec','EndTimeSec','DurationSec', ...
    'InjectFreqHz','Amplitude','TargetBandLow','TargetBandHigh', ...
    'IsTargetBandInjection','IsWrongBandInjection'});

ReportInputs = struct();
ReportInputs.Tables = struct();
ReportInputs.Tables.SyntheticInputTable = SyntheticInputTable;
ReportInputs.RunID = 'synthetic_metadata_test';

%% ===== GENERATE REPORT =====
% The report should save synthetic_input_metadata.csv and document it.
Report = nf_make_marc_validation_report(ReportInputs, RTConfig);

metadataCsv = fullfile(Report.ReportDir, 'synthetic_input_metadata.csv');
assert(exist(Report.ReportDir, 'dir') ~= 0, 'Report directory was not created.');
assert(exist(Report.SummaryPath, 'file') ~= 0, 'summary.mat was not created.');
assert(exist(Report.ReadmePath, 'file') ~= 0, 'README was not created.');
assert(exist(metadataCsv, 'file') ~= 0, 'synthetic_input_metadata.csv was not created.');

readmeText = fileread(Report.ReadmePath);
assert(contains(readmeText, 'Synthetic input design'), ...
    'README does not include the synthetic input design section.');
assert(contains(readmeText, 'synthetic_input_metadata.csv'), ...
    'README does not mention the synthetic input metadata CSV.');
assert(isempty(findall(0, 'Type', 'figure')), ...
    'Marc report generation left a figure open.');

end

function local_cleanup(tempRoot)
close(findall(0, 'Type', 'figure'));
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
