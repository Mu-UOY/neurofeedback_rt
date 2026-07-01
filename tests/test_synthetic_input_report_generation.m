function test_synthetic_input_report_generation()
% TEST_SYNTHETIC_INPUT_REPORT_GENERATION Check synthetic input visibility plots.

%% ===== CREATE TEMPORARY OUTPUT FOLDER =====
% Figures should be generated headlessly and cleaned up after the test.
close(findall(0, 'Type', 'figure'));
tempRoot = tempname();
mkdir(tempRoot);
cleanupObj = onCleanup(@() local_cleanup(tempRoot)); %#ok<NASGU>

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Analysis.FastMode = true;
RTConfig.Analysis.DisplayMode = 'off';

%% ===== CREATE SYNTHETIC INPUT AND DETECTION TRACE =====
% The detection trace is intentionally simple and aligned to block centers.
[Data, BlockInfo] = nf_make_synthetic_theta_dataset(RTConfig);
Measures = local_measures_for_blocks(BlockInfo, [0 1.2 0.1], RTConfig.Fs);

%% ===== GENERATE SYNTHETIC INPUT FIGURES =====
% At least schedule/raw/input-vs-output figures should be possible.
FigurePaths = nf_plot_synthetic_input_report(Data, BlockInfo, Measures, RTConfig, tempRoot, ...
    'TitlePrefix', 'Test synthetic input', ...
    'ControlType', 'theta_positive');

assert(numel(FigurePaths) >= 2, 'Synthetic input report created too few PNG files.');
assert(all(cellfun(@(p) exist(p, 'file') ~= 0, FigurePaths)), ...
    'Synthetic input report returned a missing PNG path.');
assert(isempty(findall(0, 'Type', 'figure')), ...
    'Synthetic input report left a figure open in headless mode.');

end

function Measures = local_measures_for_blocks(BlockInfo, zValues, Fs)
% Create one valid Measure at each block center.
nBlocks = numel(BlockInfo.Labels);
Measures = repmat(nf_measure_empty(), 1, nBlocks);
for iBlock = 1:nBlocks
    centerSample = round((BlockInfo.StartSample(iBlock) + BlockInfo.EndSample(iBlock)) ./ 2);
    Measures(iBlock).SampleIndex = centerSample;
    Measures(iBlock).WindowCenterSample = centerSample;
    Measures(iBlock).Time = centerSample ./ Fs;
    Measures(iBlock).ZRaw = zValues(iBlock);
    Measures(iBlock).ZClipped = zValues(iBlock);
    Measures(iBlock).ZSmoothed = zValues(iBlock);
    Measures(iBlock).Power = zValues(iBlock) + 10;
    Measures(iBlock).IsValid = true;
end
end

function local_cleanup(tempRoot)
close(findall(0, 'Type', 'figure'));
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
