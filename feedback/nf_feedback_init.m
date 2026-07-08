function Feedback = nf_feedback_init(RTConfig)
% NF_FEEDBACK_INIT Initialize feedback display state.
%
% USAGE:  Feedback = nf_feedback_init(RTConfig)
%
% DESCRIPTION:
%     Opens the configured feedback display backend. This function does not
%     perform z-score mapping, source acquisition, logging, or safety checks.

%% ===== INITIALIZE FEEDBACK STRUCT =====
% Stable fields make close/update safe even when setup fails partway.
Modes = nf_modes();
Feedback = local_empty_feedback(RTConfig);

if ~isfield(RTConfig, 'Feedback') || ~isfield(RTConfig.Feedback, 'Mode')
    Feedback.Mode = Modes.Feedback.None;
    Feedback.Backend = 'none';
    return;
end

Feedback.Mode = char(RTConfig.Feedback.Mode);

%% ===== HANDLE MODES WITHOUT DISPLAY SURFACES =====
% none/debug_value never open a window in this display layer.
if strcmp(Feedback.Mode, Modes.Feedback.None) || ...
        strcmp(Feedback.Mode, Modes.Feedback.DebugValue)
    Feedback.Backend = 'none';
    return;
end

if ~strcmp(Feedback.Mode, Modes.Feedback.LocalCircle)
    error('Unsupported feedback display mode: %s', Feedback.Mode);
end

%% ===== SELECT LOCAL-CIRCLE BACKEND =====
% Live FieldTrip with PTB required must not silently fall back to debug_plot.
sourceMode = local_get_nested_text(RTConfig, {'Source','Mode'}, '');
requiresPTBLive = strcmp(sourceMode, Modes.Source.LiveFieldTrip) && ...
    local_get_nested_logical(RTConfig, {'Feedback','RequirePsychtoolboxForLive'}, false);
allowDebugPlot = local_get_nested_logical(RTConfig, {'Feedback','AllowDebugPlotFallback'}, false);
hasPTB = local_has_psychtoolbox();

if requiresPTBLive
    if ~hasPTB
        error(['Psychtoolbox Screen is required for live_fieldtrip local_circle feedback. ' ...
            'Disable RequirePsychtoolboxForLive only for mock/local debug_plot tests.']);
    end
    Feedback = local_open_psychtoolbox(Feedback, RTConfig);
    return;
end

if allowDebugPlot
    Feedback = local_open_debug_plot(Feedback, RTConfig);
    return;
end

if hasPTB
    Feedback = local_open_psychtoolbox(Feedback, RTConfig);
    return;
end

error('No feedback display backend available for local_circle mode.');

end

function Feedback = local_empty_feedback(RTConfig)
% Create the stable display-state struct.
Feedback = struct();
Feedback.Mode = '';
Feedback.Backend = '';
Feedback.IsOpen = false;
Feedback.UsesPsychtoolbox = false;
Feedback.UsesDebugPlot = false;
Feedback.WindowPtr = [];
Feedback.WindowRect = [];
Feedback.FigureHandle = [];
Feedback.AxesHandle = [];
Feedback.CenterPx = [NaN NaN];
Feedback.LastTargetRadiusPx = NaN;
Feedback.LastDisplayRadiusPx = NaN;
Feedback.LastUpdateTime = NaN;
Feedback.Messages = {};

instructionText = local_get_nested_text(RTConfig, ...
    {'Feedback','Circle','InstructionText'}, '');
if ~isempty(instructionText)
    Feedback.Messages{end + 1} = instructionText;
end
end

function Feedback = local_open_debug_plot(Feedback, RTConfig)
% Open a hidden MATLAB figure for local/mock display tests.
circle = RTConfig.Feedback.Circle;
maxRadius = circle.MaxRadiusPx;
margin = 1.1 .* maxRadius;

visibleMode = 'off';
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'DisplayMode') && ...
        strcmp(char(RTConfig.Analysis.DisplayMode), 'interactive')
    visibleMode = 'on';
end

bg = local_rgb01(circle.BackgroundColor);
fig = figure('Visible', visibleMode, 'Color', bg, ...
    'MenuBar', 'none', 'ToolBar', 'none', 'Name', 'neurofeedback local circle', ...
    'NumberTitle', 'off');
ax = axes('Parent', fig);
set(ax, 'Color', bg);
axis(ax, 'equal');
xlim(ax, [-margin margin]);
ylim(ax, [-margin margin]);
axis(ax, 'off');
hold(ax, 'on');

Feedback.Backend = 'debug_plot';
Feedback.IsOpen = true;
Feedback.UsesDebugPlot = true;
Feedback.UsesPsychtoolbox = false;
Feedback.FigureHandle = fig;
Feedback.AxesHandle = ax;
Feedback.CenterPx = [0 0];
end

function Feedback = local_open_psychtoolbox(Feedback, RTConfig)
% Open a minimal Psychtoolbox window for future live display checks.
circle = RTConfig.Feedback.Circle;
bg = local_rgb255(circle.BackgroundColor);
windowPtr = [];
try
    screens = Screen('Screens');
    screenNumber = max(screens);
    [windowPtr, windowRect] = Screen('OpenWindow', screenNumber, bg);
    centerPx = [(windowRect(1) + windowRect(3)) ./ 2, ...
        (windowRect(2) + windowRect(4)) ./ 2];

    Feedback.Backend = 'psychtoolbox';
    Feedback.IsOpen = true;
    Feedback.UsesPsychtoolbox = true;
    Feedback.UsesDebugPlot = false;
    Feedback.WindowPtr = windowPtr;
    Feedback.WindowRect = windowRect;
    Feedback.CenterPx = centerPx;
catch ME
    if ~isempty(windowPtr)
        try
            Screen('Close', windowPtr);
        catch
        end
    end
    error('Failed to initialize Psychtoolbox feedback display: %s', ME.message);
end
end

function tf = local_has_psychtoolbox()
% Detect the Screen function without opening a PTB window.
tf = exist('Screen', 'file') ~= 0 || exist('Screen', 'builtin') ~= 0;
end

function value = local_get_nested_text(S, path, defaultValue)
% Read nested text with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if ischar(current) || isstring(current)
    value = char(current);
end
end

function value = local_get_nested_logical(S, path, defaultValue)
% Read nested logical flags with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
if islogical(current) && isscalar(current)
    value = current;
elseif isnumeric(current) && isscalar(current) && isfinite(current)
    value = current ~= 0;
end
end

function color = local_rgb01(colorIn)
% Convert RGB triplets to MATLAB figure color units.
color = double(colorIn(:)');
if any(color > 1)
    color = color ./ 255;
end
color = min(max(color, 0), 1);
end

function color = local_rgb255(colorIn)
% Convert RGB triplets to PTB color units.
color = double(colorIn(:)');
if all(color <= 1)
    color = color .* 255;
end
color = min(max(color, 0), 255);
end
