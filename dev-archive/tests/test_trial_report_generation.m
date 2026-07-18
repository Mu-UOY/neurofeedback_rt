function test_trial_report_generation()
% TEST_TRIAL_REPORT_GENERATION Check headless trial report plotting.

%% ===== CREATE TEMPORARY OUTPUT FOLDER =====
% Figures should be written outside repository outputs and then cleaned up.
close(findall(0, 'Type', 'figure'));
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_cleanup(tempRoot)); %#ok<NASGU>

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Analysis.DisplayMode = 'off';
RTConfig.Analysis.ReportRoot = tempRoot;

%% ===== BUILD MINIMAL BASELINE AND MEASURES =====
% Include enough data to produce at least one plot.
Baseline = struct();
Baseline.Values = [1 2 3 4 5];
Baseline.TrimmedValues = [2 3 4];
Baseline.RawValues = [1 2 3 4 5];
Baseline.NTrimmedRejected = 2;
Baseline.Mean = 3;
Baseline.Std = 1;

Measures = repmat(nf_measure_empty(), 1, 5);
for iMeasure = 1:numel(Measures)
    Measures(iMeasure).SampleIndex = iMeasure .* 100;
    Measures(iMeasure).Power = iMeasure;
    Measures(iMeasure).ZRaw = iMeasure ./ 10;
    Measures(iMeasure).ZClipped = iMeasure ./ 10;
    Measures(iMeasure).ZSmoothed = iMeasure ./ 10;
    Measures(iMeasure).FeedbackValue = iMeasure ./ 10;
    Measures(iMeasure).IsValid = true;
end
TrialSummary = struct();
TrialSummary.NValidMeasures = numel(Measures);

%% ===== GENERATE PLOTS =====
% Headless plotting should save PNGs and close every figure.
FigurePaths = nf_plot_trial_report(Baseline, Measures, TrialSummary, RTConfig, tempRoot);

assert(~isempty(FigurePaths), 'Trial report did not create any PNG files.');
assert(all(cellfun(@(p) exist(p, 'file') ~= 0, FigurePaths)), ...
    'Trial report returned a missing PNG path.');
assert(isempty(findall(0, 'Type', 'figure')), ...
    'Trial report left a figure open in headless mode.');

end

function local_cleanup(tempRoot)
close(findall(0, 'Type', 'figure'));
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
