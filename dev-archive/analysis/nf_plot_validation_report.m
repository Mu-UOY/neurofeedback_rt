function FigurePaths = nf_plot_validation_report(Results, Ref, Measures, RTConfig, OutputDir)
% NF_PLOT_VALIDATION_REPORT Save headless validation diagnostic PNGs.
%
% USAGE:  FigurePaths = nf_plot_validation_report(Results, Ref, Measures, RTConfig, OutputDir)
%
% DESCRIPTION:
%     Creates whatever validation plots can be supported by the provided
%     Results/Ref/Measures structs. Missing data are skipped without error.

%% ===== PARSE INPUTS =====
% OutputDir is created on demand and returned paths are verified PNG files.
if nargin < 4 || isempty(RTConfig)
    RTConfig = struct();
end
if nargin < 5 || isempty(OutputDir)
    OutputDir = fullfile(pwd, 'validation_report_figures');
end
OutputDir = local_absolute_path(OutputDir);
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

FigurePaths = {};

%% ===== PSD / FFT EVIDENCE =====
% Prefer the global PSD summary produced by nf_validate_fft_comparison.
[freq, psdPower] = local_psd_data(Results);
if ~isempty(freq) && ~isempty(psdPower)
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'validation_psd_fft', @(fig) local_plot_psd(fig, freq, psdPower, RTConfig));
end

%% ===== WINDOWED TARGET-BAND TRACE =====
% Plot windowed FFT target power when available.
windowedPower = local_get_nested_numeric_vector(Results, {'Step1','FFT','WindowedFFT','Power'});
if any(isfinite(windowedPower))
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'validation_windowed_fft_power', @(fig) local_plot_vector(fig, ...
        1:numel(windowedPower), windowedPower, 'Window', 'Target-band power', ...
        'Windowed FFT target-band power'));
end

%% ===== OFFLINE REFERENCE VS STREAMING =====
% Compare reference and streaming powers using available sample/time axes.
[refX, refPower] = local_ref_trace(Ref);
[streamX, streamPower] = local_measure_trace(Measures, 'Power');
if any(isfinite(refPower)) && any(isfinite(streamPower))
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'validation_power_trace', @(fig) local_plot_ref_vs_stream(fig, ...
        refX, refPower, streamX, streamPower, Results));
end

%% ===== RUNTIME DIAGNOSTICS =====
% Runtime may be scalar metrics or only a status/message summary.
if isstruct(Results) && isfield(Results, 'Runtime') && isstruct(Results.Runtime)
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'validation_runtime_diagnostics', @(fig) local_plot_runtime(fig, Results.Runtime));
end

%% ===== INVALID-WINDOW TIMELINE =====
% Plot valid/invalid and gap/drop/artifact flags when Measures are available.
if isstruct(Measures) && ~isempty(Measures)
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'validation_invalid_timeline', @(fig) local_plot_invalid_timeline(fig, Measures));
end

%% ===== DELAY / ALIGNMENT DIAGNOSTICS =====
% Delay metrics are summarized as a compact bar plot when present.
if isstruct(Results) && isfield(Results, 'Delay') && isstruct(Results.Delay)
    FigurePaths = local_try_plot(FigurePaths, RTConfig, OutputDir, ...
        'validation_delay_diagnostics', @(fig) local_plot_delay(fig, Results.Delay));
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

function [freq, psdPower] = local_psd_data(Results)
% Extract global PSD frequency and mean power.
freq = local_get_nested_numeric_vector(Results, {'Step1','FFT','GlobalPSD','Frequency'});
psdPower = local_get_nested_numeric_vector(Results, {'Step1','FFT','GlobalPSD','PowerMean'});
if isempty(psdPower) || ~any(isfinite(psdPower))
    rawPower = local_get_nested_value(Results, {'Step1','FFT','GlobalPSD','Power'}, []);
    if isnumeric(rawPower) && ~isempty(rawPower)
        if size(rawPower, 2) == numel(freq)
            psdPower = mean(rawPower, 1);
        elseif size(rawPower, 1) == numel(freq)
            psdPower = mean(rawPower, 2)';
        else
            psdPower = reshape(rawPower, 1, []);
        end
    end
end
freq = reshape(freq, 1, []);
psdPower = reshape(psdPower, 1, []);
n = min(numel(freq), numel(psdPower));
freq = freq(1:n);
psdPower = psdPower(1:n);
end

function local_plot_psd(~, freq, psdPower, RTConfig)
% Plot PSD evidence and target-band bounds when available.
plot(freq, psdPower, 'LineWidth', 1);
hold on;
band = local_target_band(RTConfig);
if all(isfinite(band))
    yl = ylim();
    plot([band(1) band(1)], yl, 'k:');
    plot([band(2) band(2)], yl, 'k:');
end
grid on;
xlabel('Frequency (Hz)');
ylabel('Power');
title('Global PSD / FFT evidence');
end

function local_plot_vector(~, x, y, xLabelText, yLabelText, titleText)
% Plot one vector trace.
plot(x, y, 'LineWidth', 1);
grid on;
xlabel(xLabelText);
ylabel(yLabelText);
title(titleText);
end

function local_plot_ref_vs_stream(~, refX, refPower, streamX, streamPower, Results)
% Plot offline reference and simulated-online power traces.
plot(refX, refPower, 'LineWidth', 1);
hold on;
plot(streamX, streamPower, 'LineWidth', 1);
grid on;
xlabel(local_axis_label(refX, streamX));
ylabel('Power');
legend({'Offline reference','Simulated online'}, 'Location', 'best');

corrValue = local_get_nested_numeric_scalar(Results, {'Compare','Correlation'}, NaN);
rmseValue = local_get_nested_numeric_scalar(Results, {'Compare','RMSE'}, NaN);
if isfinite(corrValue) || isfinite(rmseValue)
    title(sprintf('Offline vs simulated online (corr %.3g, RMSE %.3g)', corrValue, rmseValue));
else
    title('Offline vs simulated online');
end
end

function local_plot_runtime(~, Runtime)
% Plot runtime metrics or a text-only summary.
metrics = [ ...
    local_numeric_field(Runtime, 'MeanRuntimeSecs'), ...
    local_numeric_field(Runtime, 'MaxRuntimeSecs'), ...
    local_numeric_field(Runtime, 'StdRuntimeSecs')];
if any(isfinite(metrics))
    bar(metrics);
    set(gca, 'XTickLabel', {'Mean','Max','Std'});
    ylabel('Seconds');
    title('Runtime diagnostics');
else
    axis off;
    text(0.05, 0.75, ['Status: ', local_text_field(Runtime, 'Status')], 'Interpreter', 'none');
    text(0.05, 0.55, ['Message: ', local_text_field(Runtime, 'Message')], 'Interpreter', 'none');
    title('Runtime diagnostics');
end
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
title('Invalid-window timeline');
end

function local_plot_delay(~, Delay)
% Plot scalar delay/alignment diagnostics when available.
labels = {};
values = [];
fields = {'EmpiricalDelaySamples','AnalyticGroupDelaySamples','DelayCorrectionUsed', ...
    'BestLagSteps','XCorrPeak'};
for iField = 1:numel(fields)
    value = local_numeric_field(Delay, fields{iField});
    if isfinite(value)
        labels{end + 1} = fields{iField}; %#ok<AGROW>
        values(end + 1) = value; %#ok<AGROW>
    end
end
if isempty(values)
    axis off;
    text(0.05, 0.65, ['Message: ', local_text_field(Delay, 'Message')], 'Interpreter', 'none');
else
    bar(values);
    set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 25);
    ylabel('Value');
end
title('Delay / alignment diagnostics');
end

function [x, power] = local_ref_trace(Ref)
% Extract reference x-axis and power trace.
power = local_struct_numeric(Ref, 'Power');
valid = local_struct_logical(Ref, 'IsValid', true(size(power)));
power(~valid) = NaN;
x = local_struct_numeric(Ref, 'SampleIndex');
if isempty(x) || ~any(isfinite(x))
    x = local_struct_numeric(Ref, 'Time');
end
if isempty(x) || ~any(isfinite(x))
    x = 1:numel(power);
end
x = reshape(x, 1, []);
power = reshape(power, 1, []);
n = min(numel(x), numel(power));
x = x(1:n);
power = power(1:n);
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

function values = local_struct_numeric(S, fieldName)
% Extract a numeric vector from a scalar struct field.
values = [];
if isstruct(S) && isfield(S, fieldName) && isnumeric(S.(fieldName))
    values = reshape(double(S.(fieldName)), 1, []);
end
end

function values = local_struct_logical(S, fieldName, defaultValue)
% Extract a logical vector from a scalar struct field.
values = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    fieldValue = S.(fieldName);
    if islogical(fieldValue)
        values = reshape(fieldValue, 1, []);
    elseif isnumeric(fieldValue)
        values = reshape(fieldValue ~= 0, 1, []);
    end
end
end

function value = local_get_nested_value(S, path, defaultValue)
% Read a nested field with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
value = current;
end

function values = local_get_nested_numeric_vector(S, path)
% Read a nested numeric vector.
values = [];
value = local_get_nested_value(S, path, []);
if isnumeric(value)
    values = reshape(double(value), 1, []);
end
end

function value = local_get_nested_numeric_scalar(S, path, defaultValue)
% Read a nested numeric scalar.
value = defaultValue;
raw = local_get_nested_value(S, path, []);
if isnumeric(raw) && ~isempty(raw)
    value = double(raw(1));
elseif islogical(raw) && ~isempty(raw)
    value = double(raw(1));
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

function value = local_text_field(S, fieldName)
% Read a text field.
value = '';
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    fieldValue = S.(fieldName);
    if ischar(fieldValue) || isstring(fieldValue)
        value = char(fieldValue);
    elseif isnumeric(fieldValue) || islogical(fieldValue)
        value = num2str(fieldValue(1));
    end
end
end

function band = local_target_band(RTConfig)
% Read configured target band.
band = [NaN NaN];
if isfield(RTConfig, 'TargetBand') && isnumeric(RTConfig.TargetBand) && numel(RTConfig.TargetBand) >= 2
    band = double(RTConfig.TargetBand(1:2));
end
end

function label = local_axis_label(refX, streamX)
% Label the x-axis generically.
refLooksInteger = all(abs(refX - round(refX)) < eps);
streamLooksInteger = all(abs(streamX - round(streamX)) < eps);
if refLooksInteger && streamLooksInteger
    label = 'Sample index';
else
    label = 'Time / index';
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
