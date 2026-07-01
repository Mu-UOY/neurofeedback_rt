function FigurePaths = nf_plot_synthetic_input_report(SyntheticData, BlockInfo, DetectionMeasures, RTConfig, OutputDir, varargin)
% NF_PLOT_SYNTHETIC_INPUT_REPORT Save synthetic input visibility plots.
%
% USAGE:  FigurePaths = nf_plot_synthetic_input_report(Data, BlockInfo, Measures, RTConfig, OutputDir)
%         FigurePaths = nf_plot_synthetic_input_report(..., 'ControlType', controlType)
%
% DESCRIPTION:
%     Creates headless-safe plots showing the known synthetic block schedule,
%     raw synthetic input signal, and the relation between known injected
%     input and detected target-band power or z-score.

%% ===== PARSE INPUTS =====
% BlockInfo may be supplied directly or stored in SyntheticData.Metadata.
if nargin < 2 || isempty(BlockInfo)
    BlockInfo = local_block_info_from_data(SyntheticData);
end
if nargin < 3
    DetectionMeasures = [];
end
if nargin < 4 || isempty(RTConfig)
    RTConfig = struct();
end
if nargin < 5 || isempty(OutputDir)
    OutputDir = fullfile(pwd, 'synthetic_input_figures');
end
opts = local_parse_options(varargin{:});

OutputDir = local_absolute_path(OutputDir);
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

FigurePaths = {};
prefix = local_filename_prefix(opts.ControlType);

%% ===== BLOCK DESIGN TIMELINE =====
% The timeline answers what was injected and when.
if isstruct(BlockInfo) && local_has_block_bounds(BlockInfo)
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        [prefix '_input_block_design'], @(fig) local_plot_block_design(fig, ...
        BlockInfo, RTConfig, opts));
end

%% ===== RAW SYNTHETIC SIGNAL TRACE =====
% Plot the first channel fed into the algorithm, decimated only for display.
if isstruct(SyntheticData) && isfield(SyntheticData, 'X') && isnumeric(SyntheticData.X) && ...
        ~isempty(SyntheticData.X)
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        [prefix '_raw_signal_trace'], @(fig) local_plot_raw_signal(fig, ...
        SyntheticData, BlockInfo, opts));
end

%% ===== INJECTION VERSUS DETECTED OUTPUT =====
% This plot links known input to the algorithm-derived output trace.
[detX, detValues, detLabel] = local_detection_trace(DetectionMeasures);
if isstruct(BlockInfo) && local_has_block_bounds(BlockInfo) && ~isempty(detValues) && any(isfinite(detValues))
    if strcmp(opts.ControlType, 'wrong_band')
        baseName = [prefix '_input_vs_target_power'];
    else
        baseName = [prefix '_injection_vs_detected_power'];
    end
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        baseName, @(fig) local_plot_injection_vs_detected(fig, SyntheticData, ...
        BlockInfo, detX, detValues, detLabel, RTConfig, opts));
end

end

function FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, baseName, plotFcn)
% Create, save, and close one figure without leaking figure handles.
fig = [];
try
    fig = local_new_figure(RTConfig);
    plotFcn(fig);
    outPath = local_save_png(fig, OutputDir, baseName);
    if ~isempty(outPath)
        FigurePaths{end + 1} = outPath; %#ok<AGROW>
    end
catch ME
    warning('Plot skipped (%s): %s', baseName, ME.message);
    if ~isempty(fig) && ishandle(fig)
        close(fig);
    end
end
end

function fig = local_new_figure(RTConfig)
% Create a headless figure unless interactive display is explicitly requested.
visibleMode = 'off';
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'DisplayMode') && ...
        strcmp(char(RTConfig.Analysis.DisplayMode), 'interactive')
    visibleMode = 'on';
end
fig = figure('Visible', visibleMode);
end

function outPath = local_save_png(fig, OutputDir, baseName)
% Save using the base-path-without-extension rule and close the figure.
outPath = '';
basePath = fullfile(OutputDir, baseName);
try
    print(fig, basePath, '-dpng', '-r150');
    expectedPngPath = [basePath '.png'];
    if exist(expectedPngPath, 'file') ~= 0
        outPath = local_absolute_path(expectedPngPath);
    end
catch ME
    warning('Could not save plot %s: %s', baseName, ME.message);
end
if ishandle(fig)
    close(fig);
end
end

function opts = local_parse_options(varargin)
% Parse optional name/value arguments.
opts = struct();
opts.TitlePrefix = '';
opts.ControlType = 'theta_positive';
opts.Ref = [];
opts.Results = [];

if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('Optional arguments must be name/value pairs.');
end
for iArg = 1:2:numel(varargin)
    name = char(varargin{iArg});
    value = varargin{iArg + 1};
    switch lower(name)
        case 'titleprefix'
            opts.TitlePrefix = char(value);
        case 'controltype'
            opts.ControlType = char(value);
        case 'ref'
            opts.Ref = value;
        case 'results'
            opts.Results = value;
    end
end
end

function prefix = local_filename_prefix(controlType)
% Build distinct filenames for theta-positive and wrong-band controls.
controlType = char(controlType);
if isempty(controlType)
    prefix = 'synthetic';
else
    prefix = regexprep(lower(controlType), '[^a-z0-9]+', '_');
    prefix = regexprep(prefix, '^_|_$', '');
    if isempty(prefix)
        prefix = 'synthetic';
    end
end
end

function BlockInfo = local_block_info_from_data(SyntheticData)
% Read BlockInfo from Data.Metadata when not supplied directly.
BlockInfo = [];
if isstruct(SyntheticData) && isfield(SyntheticData, 'Metadata') && ...
        isfield(SyntheticData.Metadata, 'BlockInfo')
    BlockInfo = SyntheticData.Metadata.BlockInfo;
end
end

function tf = local_has_block_bounds(BlockInfo)
% Check the fields needed for block plotting.
tf = isfield(BlockInfo, 'Labels') && isfield(BlockInfo, 'StartSample') && ...
    isfield(BlockInfo, 'EndSample') && ~isempty(BlockInfo.Labels);
end

function local_plot_block_design(~, BlockInfo, RTConfig, opts)
% Plot block schedule with injected frequency/amplitude annotations.
[labels, startSample, endSample, startTime, endTime, freqHz, amplitude] = ...
    local_block_arrays(BlockInfo, RTConfig);
targetBand = local_target_band(RTConfig);
nBlocks = numel(labels);

hold on;
for iBlock = 1:nBlocks
    x0 = startTime(iBlock);
    x1 = endTime(iBlock);
    if ~isfinite(x0) || ~isfinite(x1) || x1 <= x0
        x0 = startSample(iBlock);
        x1 = endSample(iBlock);
    end
    width = max(eps, x1 - x0);
    insideTarget = isfinite(freqHz(iBlock)) && all(isfinite(targetBand)) && ...
        freqHz(iBlock) >= targetBand(1) && freqHz(iBlock) <= targetBand(2) && ...
        isfinite(amplitude(iBlock)) && amplitude(iBlock) ~= 0;
    faceColor = local_block_face_color(insideTarget, freqHz(iBlock), amplitude(iBlock));
    rectangle('Position', [x0 0 width 1], 'FaceColor', faceColor, ...
        'EdgeColor', [0 0 0], 'LineWidth', 0.75);
    annotationText = local_block_annotation(labels{iBlock}, freqHz(iBlock), ...
        amplitude(iBlock), insideTarget);
    text(x0 + width ./ 2, 0.5, annotationText, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Interpreter', 'none', ...
        'Color', [0 0 0], 'FontWeight', 'bold', 'FontSize', 8, ...
        'BackgroundColor', [1 1 1], 'Margin', 1);
end
ylim([0 1]);
set(gca, 'YTick', []);
xlabel('Time (s) or sample index');
title(local_title(opts, 'Synthetic input block design'));
grid on;
end

function local_plot_raw_signal(~, SyntheticData, BlockInfo, opts)
% Plot the first channel of the synthetic input.
x = local_data_axis(SyntheticData);
y = double(SyntheticData.X(1, :));
[xPlot, yPlot] = local_decimate_for_plot(x, y, 4000);
plot(xPlot, yPlot, 'LineWidth', 1);
hold on;
local_add_block_boundaries(BlockInfo, SyntheticData);
grid on;
xlabel(local_data_axis_label(SyntheticData));
ylabel('Amplitude');
title(local_title(opts, 'Raw synthetic signal trace'));
end

function local_plot_injection_vs_detected(~, SyntheticData, BlockInfo, detX, detValues, detLabel, RTConfig, opts)
% Plot known injection indicator and detected target-band output.
[injX, injection] = local_injection_indicator(SyntheticData, BlockInfo, RTConfig, opts.ControlType);

subplot(2, 1, 1);
plot(injX, injection, 'LineWidth', 1);
hold on;
local_add_block_boundaries(BlockInfo, SyntheticData);
grid on;
ylabel('Known input');
title(local_title(opts, 'Known injection versus detected target-band output'));

subplot(2, 1, 2);
plot(detX, detValues, 'LineWidth', 1);
grid on;
xlabel('Time / sample / measure index');
ylabel(detLabel);
title(['Detected ', detLabel], 'Interpreter', 'none');
end

function [labels, startSample, endSample, startTime, endTime, freqHz, amplitude] = local_block_arrays(BlockInfo, RTConfig)
% Normalize block metadata arrays.
labels = local_labels(BlockInfo);
nBlocks = numel(labels);
startSample = local_numeric_field(BlockInfo, 'StartSample', nBlocks);
endSample = local_numeric_field(BlockInfo, 'EndSample', nBlocks);
startTime = local_time_field(BlockInfo, {'StartTimeSec','StartTime'}, nBlocks);
endTime = local_time_field(BlockInfo, {'EndTimeSec','EndTime'}, nBlocks);
freqHz = local_numeric_field(BlockInfo, 'InjectFreqHz', nBlocks);
amplitude = local_numeric_field(BlockInfo, 'Amplitude', nBlocks);

if any(~isfinite(startTime)) && isfield(RTConfig, 'Fs') && isfinite(RTConfig.Fs) && RTConfig.Fs > 0
    missing = ~isfinite(startTime) & isfinite(startSample);
    startTime(missing) = (startSample(missing) - 1) ./ RTConfig.Fs;
end
if any(~isfinite(endTime)) && isfield(RTConfig, 'Fs') && isfinite(RTConfig.Fs) && RTConfig.Fs > 0
    missing = ~isfinite(endTime) & isfinite(endSample);
    endTime(missing) = (endSample(missing) - 1) ./ RTConfig.Fs;
end
end

function labels = local_labels(BlockInfo)
% Normalize block labels.
labels = {};
if isfield(BlockInfo, 'Labels')
    if iscell(BlockInfo.Labels)
        labels = BlockInfo.Labels(:)';
    elseif isstring(BlockInfo.Labels)
        labels = cellstr(BlockInfo.Labels(:))';
    elseif ischar(BlockInfo.Labels)
        labels = cellstr(BlockInfo.Labels)';
    end
end
for iLabel = 1:numel(labels)
    labels{iLabel} = char(labels{iLabel});
end
end

function [x, values, label] = local_detection_trace(Measures)
% Prefer z-score traces, then Power.
fields = {'ZSmoothed','ZClipped','ZRaw','Power'};
x = [];
values = [];
label = 'Power';
if ~isstruct(Measures) || isempty(Measures)
    return;
end
for iField = 1:numel(fields)
    candidate = local_measure_numeric(Measures, fields{iField});
    if any(isfinite(candidate))
        values = candidate;
        label = fields{iField};
        break;
    end
end
if isempty(values)
    return;
end
x = local_measure_axis(Measures);
isValid = local_measure_logical(Measures, 'IsValid', true);
values(~isValid) = NaN;
n = min(numel(x), numel(values));
x = x(1:n);
values = values(1:n);
end

function [x, injection] = local_injection_indicator(SyntheticData, BlockInfo, RTConfig, controlType)
% Build known injection amplitude over the synthetic data axis.
x = local_data_axis(SyntheticData);
injection = zeros(size(x));
[~, startSample, endSample, ~, ~, freqHz, amplitude] = local_block_arrays(BlockInfo, RTConfig);
targetBand = local_target_band(RTConfig);
for iBlock = 1:numel(startSample)
    if ~isfinite(startSample(iBlock)) || ~isfinite(endSample(iBlock)) || ...
            ~isfinite(freqHz(iBlock)) || ~isfinite(amplitude(iBlock))
        continue;
    end
    idx = max(1, round(startSample(iBlock))):min(numel(injection), round(endSample(iBlock)));
    insideTarget = all(isfinite(targetBand)) && freqHz(iBlock) >= targetBand(1) && ...
        freqHz(iBlock) <= targetBand(2);
    if strcmp(char(controlType), 'wrong_band')
        useBlock = ~insideTarget && amplitude(iBlock) ~= 0;
    else
        useBlock = insideTarget && amplitude(iBlock) ~= 0;
    end
    if useBlock
        injection(idx) = amplitude(iBlock);
    end
end
end

function local_add_block_boundaries(BlockInfo, SyntheticData)
% Overlay vertical block boundaries when block info is available.
if isempty(BlockInfo) || ~isstruct(BlockInfo) || ~local_has_block_bounds(BlockInfo)
    return;
end
xAxis = local_data_axis(SyntheticData);
useTime = isfield(SyntheticData, 'Time') && ~isempty(SyntheticData.Time);
startValues = local_time_field(BlockInfo, {'StartTimeSec','StartTime'}, numel(local_labels(BlockInfo)));
endValues = local_time_field(BlockInfo, {'EndTimeSec','EndTime'}, numel(local_labels(BlockInfo)));
if ~useTime || all(~isfinite(startValues))
    startValues = local_numeric_field(BlockInfo, 'StartSample', numel(local_labels(BlockInfo)));
    endValues = local_numeric_field(BlockInfo, 'EndSample', numel(local_labels(BlockInfo)));
end
yl = ylim();
boundaries = unique([startValues(:); endValues(:)]);
for iBoundary = 1:numel(boundaries)
    if isfinite(boundaries(iBoundary)) && boundaries(iBoundary) >= min(xAxis) && boundaries(iBoundary) <= max(xAxis)
        line([boundaries(iBoundary) boundaries(iBoundary)], yl, 'LineStyle', ':', 'Color', [0 0 0]);
    end
end
ylim(yl);
end

function x = local_data_axis(SyntheticData)
% Use Data.Time when available, otherwise sample index.
if isstruct(SyntheticData) && isfield(SyntheticData, 'Time') && ~isempty(SyntheticData.Time)
    x = reshape(double(SyntheticData.Time), 1, []);
else
    x = 1:size(SyntheticData.X, 2);
end
end

function label = local_data_axis_label(SyntheticData)
% Label the raw data axis.
if isstruct(SyntheticData) && isfield(SyntheticData, 'Time') && ~isempty(SyntheticData.Time)
    label = 'Time (s)';
else
    label = 'Sample index';
end
end

function [xPlot, yPlot] = local_decimate_for_plot(x, y, maxPoints)
% Decimate for plotting only.
n = numel(y);
step = max(1, ceil(n ./ maxPoints));
idx = 1:step:n;
xPlot = x(idx);
yPlot = y(idx);
end

function values = local_measure_numeric(Measures, fieldName)
% Extract a numeric vector from a Measure struct array.
values = NaN(1, numel(Measures));
if ~isfield(Measures, fieldName)
    return;
end
for iMeasure = 1:numel(Measures)
    value = Measures(iMeasure).(fieldName);
    if isnumeric(value) && ~isempty(value)
        values(iMeasure) = double(value(1));
    elseif islogical(value) && ~isempty(value)
        values(iMeasure) = double(value(1));
    end
end
end

function x = local_measure_axis(Measures)
% Use time or sample fields when available.
x = local_measure_numeric(Measures, 'Time');
if ~any(isfinite(x))
    x = local_measure_numeric(Measures, 'SampleIndex');
end
if ~any(isfinite(x))
    x = local_measure_numeric(Measures, 'WindowCenterSample');
end
if ~any(isfinite(x))
    x = 1:numel(Measures);
end
end

function values = local_measure_logical(Measures, fieldName, defaultValue)
% Extract a logical vector from Measures.
values = repmat(logical(defaultValue), 1, numel(Measures));
if ~isfield(Measures, fieldName)
    return;
end
for iMeasure = 1:numel(Measures)
    value = Measures(iMeasure).(fieldName);
    if islogical(value) && ~isempty(value)
        values(iMeasure) = logical(value(1));
    elseif isnumeric(value) && ~isempty(value) && isfinite(value(1))
        values(iMeasure) = value(1) ~= 0;
    end
end
end

function values = local_numeric_field(S, fieldName, nRows)
% Extract numeric vector from BlockInfo.
values = NaN(1, nRows);
if isfield(S, fieldName) && isnumeric(S.(fieldName))
    raw = reshape(double(S.(fieldName)), 1, []);
    n = min(nRows, numel(raw));
    values(1:n) = raw(1:n);
end
end

function values = local_time_field(S, fieldNames, nRows)
% Extract time vector from BlockInfo with fallback names.
values = NaN(1, nRows);
for iField = 1:numel(fieldNames)
    if isfield(S, fieldNames{iField}) && isnumeric(S.(fieldNames{iField}))
        raw = reshape(double(S.(fieldNames{iField})), 1, []);
        n = min(nRows, numel(raw));
        values(1:n) = raw(1:n);
        return;
    end
end
end

function targetBand = local_target_band(RTConfig)
% Read configured target band.
targetBand = [NaN NaN];
if isfield(RTConfig, 'TargetBand') && isnumeric(RTConfig.TargetBand) && numel(RTConfig.TargetBand) >= 2
    targetBand = reshape(double(RTConfig.TargetBand(1:2)), 1, []);
end
end

function textOut = local_inside_text(insideTarget, freqHz)
% Label whether an injected frequency is target-band.
if ~isfinite(freqHz)
    textOut = 'no injection';
elseif insideTarget
    textOut = 'inside target';
else
    textOut = 'outside target';
end
end

function faceColor = local_block_face_color(insideTarget, freqHz, amplitude)
% Use light fills so black block annotations remain readable in exports.
hasInjection = isfinite(freqHz) && isfinite(amplitude) && amplitude ~= 0;
if insideTarget
    faceColor = [0.86 0.96 0.86];
elseif hasInjection
    faceColor = [0.98 0.92 0.82];
else
    faceColor = [0.97 0.97 0.97];
end
end

function annotationText = local_block_annotation(label, freqHz, amplitude, insideTarget)
% Build readable block annotation text for exported PNG/PDF reports.
if isfinite(freqHz)
    freqText = sprintf('%.4g Hz', freqHz);
else
    freqText = 'no injection';
end
if isfinite(amplitude)
    ampText = sprintf('amp %.4g', amplitude);
else
    ampText = 'amp NaN';
end
annotationText = sprintf('%s\\n%s, %s\\n%s', label, freqText, ampText, ...
    local_inside_text(insideTarget, freqHz));
end

function titleText = local_title(opts, baseTitle)
% Add optional title prefix.
if isfield(opts, 'TitlePrefix') && ~isempty(opts.TitlePrefix)
    titleText = [opts.TitlePrefix, ': ', baseTitle];
else
    titleText = baseTitle;
end
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
