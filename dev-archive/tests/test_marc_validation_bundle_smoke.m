function test_marc_validation_bundle_smoke()
% TEST_MARC_VALIDATION_BUNDLE_SMOKE Run the fast Step 2C Marc bundle.

%% ===== CONFIGURE TEMPORARY FAST BUNDLE =====
% The bundle must not depend on participant data or repository output folders.
close(findall(0, 'Type', 'figure'));
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_cleanup(tempRoot)); %#ok<NASGU>

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Analysis.DisplayMode = 'off';
RTConfig.Analysis.FastMode = true;
RTConfig.Analysis.ReportRoot = tempRoot;
RTConfig.SessionMetadata.RunID = 'bundle_smoke';

%% ===== RUN BUNDLE =====
% The smoke bundle should create a complete Marc report from synthetic data.
Report = nf_run_marc_validation_bundle(RTConfig);

%% ===== CHECK REPORT OUTPUTS =====
% Summary, README, CSVs, and PNGs should exist in the created report folder.
assert(isstruct(Report), 'Bundle did not return a Report struct.');
assert(exist(Report.ReportDir, 'dir') ~= 0, 'Bundle report directory does not exist.');
assert(exist(Report.SummaryPath, 'file') ~= 0, 'Bundle summary.mat does not exist.');
assert(exist(Report.ReadmePath, 'file') ~= 0, 'Bundle README does not exist.');
assert(strcmp(Report.ReportDir, local_existing_dir(Report.ReportDir)), ...
    'Report.ReportDir does not point to the created folder.');
assert(iscell(Report.FigurePaths), 'Report.FigurePaths must be a cell array.');
assert(iscell(Report.TablePaths), 'Report.TablePaths must be a cell array.');
assert(any(cellfun(@(p) endsWith(p, '.csv') && exist(p, 'file') ~= 0, Report.TablePaths)), ...
    'Bundle did not create any CSV outputs.');
syntheticCsv = dir(fullfile(Report.ReportDir, '*input*.csv'));
assert(~isempty(syntheticCsv), 'Bundle did not create a synthetic input metadata CSV.');
assert(~isempty(Report.FigurePaths), 'Bundle did not create any PNG figures.');
assert(any(cellfun(@(p) endsWith(p, '.png') && exist(p, 'file') ~= 0, Report.FigurePaths)), ...
    'Bundle returned no existing PNG figure paths.');
syntheticPng = dir(fullfile(Report.ReportDir, 'figures', '*input*.png'));
assert(~isempty(syntheticPng), 'Bundle did not create synthetic input visibility PNGs.');
assert(isempty(findall(0, 'Type', 'figure')), ...
    'Bundle left a figure open in headless mode.');

end

function out = local_existing_dir(pathIn)
% Return the same path after confirming it exists.
assert(exist(pathIn, 'dir') ~= 0, 'Expected directory does not exist: %s', pathIn);
out = pathIn;
end

function local_cleanup(tempRoot)
close(findall(0, 'Type', 'figure'));
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
