function FigurePaths = nf_plot_trial_report(Baseline, Measures, TrialSummary, RTConfig, OutputDir) %#ok<INUSD>
% NF_PLOT_TRIAL_REPORT Save headless baseline/trial diagnostic PNGs.
%
% USAGE:  FigurePaths = nf_plot_trial_report(Baseline, Measures, TrialSummary, RTConfig, OutputDir)
%
% DESCRIPTION:
%     Creates whatever trial protocol plots can be supported by the provided
%     Baseline/Measures structs. Missing data are skipped without error.

%% ===== PARSE INPUTS =====
% OutputDir is created on demand and returned paths are verified PNG files.
if nargin < 4 || isempty(RTConfig)
    RTConfig = struct();
end
if nargin < 5 || isempty(OutputDir)
    OutputDir = fullfile(pwd, 'trial_report_figures');
end
OutputDir = local_absolute_path(OutputDir);
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

FigurePaths = {};

%% ===== BASELINE DISTRIBUTION =====
% Prefer usable trimmed values, then all values, then raw values.
baselineValues = local_baseline_values(Baseline);
if any(isfinite(baselineValues))
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'trial_baseline_distribution', @(fig) local_plot_baseline_distribution(fig, baselineValues));
end

%% ===== USABLE VS REJECTED BASELINE VALUES =====
% Show raw/trimmed values when rejection audit fields are available.
if isstruct(Baseline) && isfield(Baseline, 'RawValues') && isfield(Baseline, 'TrimmedValues')
    rawValues = local_numeric_vector(Baseline.RawValues);
    trimmedValues = local_numeric_vector(Baseline.TrimmedValues);
    if any(isfinite(rawValues)) && any(isfinite(trimmedValues))
        FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
            'trial_baseline_usable_rejected', @(fig) local_plot_baseline_audit(fig, ...
            rawValues, trimmedValues, Baseline));
    end
end

%% ===== TRIAL POWER TRACE =====
% Power is the primary target-band measure before z-scoring.
[x, power] = local_measure_trace(Measures, 'Power');
if any(isfinite(power))
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'trial_power_trace', @(fig) local_plot_vector(fig, x, power, ...
        'Sample / time', 'Power', 'Trial power trace'));
end

%% ===== Z-SCORE TRACES =====
% Plot available z-score fields on one axis.
if isstruct(Measures) && ~isempty(Measures)
    zRaw = local_measure_numeric(Measures, 'ZRaw');
    zClipped = local_measure_numeric(Measures, 'ZClipped');
    zSmoothed = local_measure_numeric(Measures, 'ZSmoothed');
    if any(isfinite(zRaw)) || any(isfinite(zClipped)) || any(isfinite(zSmoothed))
        FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
            'trial_zscore_traces', @(fig) local_plot_zscores(fig, ...
            local_measure_axis(Measures), zRaw, zClipped, zSmoothed));
    end
end

%% ===== FEEDBACK TRACE =====
% FeedbackValue is plotted only when finite values exist.
[xFeedback, feedbackValue] = local_measure_trace(Measures, 'FeedbackValue');
if any(isfinite(feedbackValue))
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'trial_feedback_trace', @(fig) local_plot_vector(fig, xFeedback, feedbackValue, ...
        'Sample / time', 'Feedback value', 'Feedback value trace'));
end

%% ===== INVALID-WINDOW TIMELINE =====
% Plot valid/invalid and gap/drop/artifact flags when Measures are available.
if isstruct(Measures) && ~isempty(Measures)
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'trial_invalid_timeline', @(fig) local_plot_invalid_timeline(fig, Measures));
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

function values = local_baseline_values(Baseline)
% Read baseline values using the requested preference order.
values = [];
if ~isstruct(Baseline) || isempty(Baseline)
    return;
end
if isfield(Baseline, 'TrimmedValues') && ~isempty(Baseline.TrimmedValues)
    values = local_numeric_vector(Baseline.TrimmedValues);
elseif isfield(Baseline, 'Values') && ~isempty(Baseline.Values)
    values = local_numeric_vector(Baseline.Values);
elseif isfield(Baseline, 'RawValues') && ~isempty(Baseline.RawValues)
    values = local_numeric_vector(Baseline.RawValues);
end
end

function local_plot_baseline_distribution(~, values)
% Plot a simple histogram of baseline powers.
values = values(isfinite(values));
histogram(values);
grid on;
xlabel('Baseline power');
ylabel('Count');
title('Baseline distribution');
end

function local_plot_baseline_audit(~, rawValues, trimmedValues, Baseline)
% Plot raw and usable baseline values for auditability.
plot(rawValues, 'o');
hold on;
plot(trimmedValues, 'x');
grid on;
xlabel('Value index');
ylabel('Baseline power');
legend({'Raw values','Trimmed usable values'}, 'Location', 'best');
nRejected = local_numeric_field(Baseline, 'NTrimmedRejected');
if isfinite(nRejected)
    title(sprintf('Baseline usable vs rejected values (%g rejected)', nRejected));
else
    title('Baseline usable vs rejected values');
end
end

function local_plot_vector(~, x, y, xLabelText, yLabelText, titleText)
% Plot one vector trace.
plot(x, y, 'LineWidth', 1);
grid on;
xlabel(xLabelText);
ylabel(yLabelText);
title(titleText);
end

function local_plot_zscores(~, x, zRaw, zClipped, zSmoothed)
% Plot available z-score traces.
hold on;
legendLabels = {};
if any(isfinite(zRaw))
    plot(x, zRaw, 'LineWidth', 1);
    legendLabels{end + 1} = 'ZRaw'; %#ok<AGROW>
end
if any(isfinite(zClipped))
    plot(x, zClipped, 'LineWidth', 1);
    legendLabels{end + 1} = 'ZClipped'; %#ok<AGROW>
end
if any(isfinite(zSmoothed))
    plot(x, zSmoothed, 'LineWidth', 1);
    legendLabels{end + 1} = 'ZSmoothed'; %#ok<AGROW>
end
grid on;
xlabel('Sample / time');
ylabel('Z-score');
if ~isempty(legendLabels)
    legend(legendLabels, 'Location', 'best');
end
title('Trial z-score traces');
end

function local_plot_invalid_timeline(~, Measures)
% Plot valid/invalid and common quality flags by sample or row.
x = local_measure_axis(Measures);
isValid = local_measure_logical(Measures, 'IsValid', true);
gap = local_measure_logical(Measures, 'GapInWindowFlag', false);
drop = local_measure_logical(Measures, 'DroppedChunkFlag', false);
artifact = local_measure_logical(Measures, 'ArtifactFlag', false);

plot(x, double(~isValid), 'LineWidth', 1);
hold on;
plot(x, double(gap) + 1.2, 'LineWidth', 1);
plot(x, double(drop) + 2.4, 'LineWidth', 1);
plot(x, double(artifact) + 3.6, 'LineWidth', 1);
grid on;
ylim([-0.2 5]);
xlabel('Sample / row');
ylabel('Flag lane');
legend({'Invalid','Gap','Dropped','Artifact'}, 'Location', 'best');
title('Trial invalid-window timeline');
end

function [x, values] = local_measure_trace(Measures, fieldName)
% Extract a finite measure trace and matching x-axis.
values = local_measure_numeric(Measures, fieldName);
isValid = local_measure_logical(Measures, 'IsValid', true);
values(~isValid) = NaN;
x = local_measure_axis(Measures);
n = min(numel(x), numel(values));
x = x(1:n);
values = values(1:n);
end

function x = local_measure_axis(Measures)
% Use sample center fields when available, otherwise row index.
x = local_measure_numeric(Measures, 'SampleIndex');
if ~any(isfinite(x))
    x = local_measure_numeric(Measures, 'WindowCenterSample');
end
if ~any(isfinite(x))
    x = local_measure_numeric(Measures, 'Time');
end
if ~any(isfinite(x))
    x = 1:numel(Measures);
end
x = reshape(x, 1, []);
end

function values = local_measure_numeric(Measures, fieldName)
% Extract a numeric vector from a Measure struct array.
if ~isstruct(Measures) || isempty(Measures)
    values = [];
    return;
end
values = NaN(1, numel(Measures));
if ~isfield(Measures, fieldName)
    return;
end
for i = 1:numel(Measures)
    value = Measures(i).(fieldName);
    if isnumeric(value) && ~isempty(value)
        values(i) = double(value(1));
    elseif islogical(value) && ~isempty(value)
        values(i) = double(value(1));
    end
end
end

function values = local_measure_logical(Measures, fieldName, defaultValue)
% Extract a logical vector from a Measure struct array.
values = repmat(logical(defaultValue), 1, numel(Measures));
if ~isstruct(Measures) || isempty(Measures) || ~isfield(Measures, fieldName)
    return;
end
for i = 1:numel(Measures)
    value = Measures(i).(fieldName);
    if islogical(value) && ~isempty(value)
        values(i) = logical(value(1));
    elseif isnumeric(value) && ~isempty(value) && isfinite(value(1))
        values(i) = value(1) ~= 0;
    end
end
end

function values = local_numeric_vector(valuesIn)
% Normalize a numeric/logical vector.
values = [];
if isnumeric(valuesIn) || islogical(valuesIn)
    values = reshape(double(valuesIn), 1, []);
end
end

function value = local_numeric_field(S, fieldName)
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
