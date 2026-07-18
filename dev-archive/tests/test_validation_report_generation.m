function test_validation_report_generation()
% TEST_VALIDATION_REPORT_GENERATION Check headless validation report plotting.

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

%% ===== BUILD MINIMAL VALIDATION DATA =====
% Data are intentionally small but sufficient for multiple plots.
Ref = struct();
Ref.Power = [1 2 3 4 5];
Ref.SampleIndex = [100 200 300 400 500];
Ref.Time = Ref.SampleIndex ./ RTConfig.Fs;
Ref.IsValid = true(1, 5);

Measures = repmat(nf_measure_empty(), 1, 5);
for iMeasure = 1:numel(Measures)
    Measures(iMeasure).Power = Ref.Power(iMeasure) + 0.05;
    Measures(iMeasure).SampleIndex = Ref.SampleIndex(iMeasure);
    Measures(iMeasure).Time = Ref.Time(iMeasure);
    Measures(iMeasure).IsValid = true;
end

Results = struct();
Results.Compare.Correlation = 0.99;
Results.Compare.RMSE = 0.05;
Results.Runtime.Status = 'PASS';
Results.Runtime.Message = 'ok';
Results.Delay.EmpiricalDelaySamples = 0;
Results.Delay.AnalyticGroupDelaySamples = 0;
Results.Delay.DelayCorrectionUsed = 0;
Results.Step1.FFT.GlobalPSD.Frequency = 1:10;
Results.Step1.FFT.GlobalPSD.PowerMean = 1:10;

%% ===== GENERATE PLOTS =====
% Headless plotting should save PNGs and close every figure.
FigurePaths = nf_plot_validation_report(Results, Ref, Measures, RTConfig, tempRoot);

assert(~isempty(FigurePaths), 'Validation report did not create any PNG files.');
assert(all(cellfun(@(p) exist(p, 'file') ~= 0, FigurePaths)), ...
    'Validation report returned a missing PNG path.');
assert(isempty(findall(0, 'Type', 'figure')), ...
    'Validation report left a figure open in headless mode.');

end

function local_cleanup(tempRoot)
close(findall(0, 'Type', 'figure'));
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
