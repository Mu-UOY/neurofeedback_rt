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
    Feedback.Backend = Modes.FeedbackBackend.None;
    return;
end

Feedback.Mode = char(RTConfig.Feedback.Mode);

%% ===== HANDLE MODES WITHOUT DISPLAY SURFACES =====
% none/debug_value never open a window in this display layer.
if strcmp(Feedback.Mode, Modes.Feedback.None) || ...
        strcmp(Feedback.Mode, Modes.Feedback.DebugValue)
    Feedback.Backend = Modes.FeedbackBackend.None;
    return;
end

%% ===== HANDLE EXPLICIT DEBUG-PLOT MODE =====
% DebugPlot is an explicit test/debug backend and never requires PTB.
if strcmp(Feedback.Mode, Modes.Feedback.DebugPlot)
    Feedback = local_open_debug_plot(Feedback, RTConfig);
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
backend = local_get_nested_text(RTConfig, {'Feedback','Backend'}, '');
hasPTB = local_has_psychtoolbox(RTConfig);

if strcmp(backend, Modes.FeedbackBackend.DebugPlot)
    Feedback = local_open_debug_plot(Feedback, RTConfig);
    return;
end

if strcmp(backend, Modes.FeedbackBackend.Psychtoolbox) || requiresPTBLive
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
Feedback.UsesRealPsychtoolbox = false;
Feedback.UsesHeadlessPsychtoolboxTest = false;
Feedback.ScreenNumber = NaN;
Feedback.AvailableScreens = [];
Feedback.ScreenFcn = [];
Feedback.TimeFcn = [];
Feedback.FlipWhen = 0;
Feedback.FlipAudit = struct([]);
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
Modes = nf_modes();
circle = RTConfig.Feedback.Circle;
maxRadius = circle.MaxRadiusPx;
margin = circle.DebugAxesMarginScale .* maxRadius;

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

Feedback.Backend = Modes.FeedbackBackend.DebugPlot;
Feedback.IsOpen = true;
Feedback.UsesDebugPlot = true;
Feedback.UsesPsychtoolbox = false;
Feedback.FigureHandle = fig;
Feedback.AxesHandle = ax;
Feedback.CenterPx = [0 0];
end

function Feedback = local_open_psychtoolbox(Feedback, RTConfig)
% Open a minimal Psychtoolbox window for future live display checks.
Modes = nf_modes();
circle = RTConfig.Feedback.Circle;
bg = local_rgb255(circle.BackgroundColor);
windowPtr = [];
screenFcn = local_screen_fcn(RTConfig);
displayMode = local_get_nested_text(RTConfig, {'DevelopmentSession','DisplayMode'}, '');
strictHeadless = nf_is_strict_step0_headless_contract(RTConfig);
if strcmp(displayMode, Modes.DevelopmentDisplay.HeadlessPsychtoolboxTest) && ...
        ~strictHeadless
    error('Headless Psychtoolbox feedback requires the strict Step 0 test contract.');
end
try
    screens = screenFcn('Screens');
    configuredScreen = local_get_nested_numeric(RTConfig, ...
        {'DevelopmentSession','Feedback','ScreenNumber'}, []);
    if isempty(configuredScreen)
        policy = local_get_nested_text(RTConfig, ...
            {'DevelopmentSession','Feedback','ScreenSelectionPolicy'}, ...
            Modes.ScreenSelection.HighestIndex);
        if ~strcmp(policy, Modes.ScreenSelection.HighestIndex)
            error('Unsupported Step 0 screen-selection policy: %s', policy);
        end
        screenNumber = max(screens);
    else
        screenNumber = configuredScreen;
        if ~ismember(screenNumber, screens)
            error('Configured Psychtoolbox screen is unavailable.');
        end
    end
    windowRectConfig = local_get_nested_numeric(RTConfig, ...
        {'DevelopmentSession','Feedback','WindowRect'}, []);
    if isempty(windowRectConfig)
        [windowPtr, windowRect] = screenFcn('OpenWindow', screenNumber, bg);
    else
        [windowPtr, windowRect] = screenFcn('OpenWindow', screenNumber, bg, windowRectConfig);
    end
    centerPx = [(windowRect(1) + windowRect(3)) ./ 2, ...
        (windowRect(2) + windowRect(4)) ./ 2];

    Feedback.Backend = Modes.FeedbackBackend.Psychtoolbox;
    Feedback.IsOpen = true;
    Feedback.UsesPsychtoolbox = true;
    Feedback.UsesDebugPlot = false;
    Feedback.UsesRealPsychtoolbox = strcmp(displayMode, Modes.DevelopmentDisplay.RealPsychtoolbox);
    Feedback.UsesHeadlessPsychtoolboxTest = strictHeadless;
    Feedback.ScreenNumber = screenNumber;
    Feedback.AvailableScreens = screens;
    Feedback.ScreenFcn = screenFcn;
    if strictHeadless
        Feedback.TimeFcn = local_get_nested(RTConfig, ...
            {'DevelopmentSession','TestHooks','TimeFcn'}, []);
    end
    Feedback.FlipWhen = RTConfig.DevelopmentSession.Feedback.FlipWhen;
    Feedback.WindowPtr = windowPtr;
    Feedback.WindowRect = windowRect;
    Feedback.CenterPx = centerPx;
catch ME
    if ~isempty(windowPtr)
        try
            screenFcn('Close', windowPtr);
        catch
        end
    end
    error('Failed to initialize Psychtoolbox feedback display: %s', ME.message);
end
end

function tf = local_has_psychtoolbox(RTConfig)
% Detect the Screen function without opening a PTB window.
tf = exist('Screen', 'file') ~= 0 || exist('Screen', 'builtin') ~= 0 || ...
    nf_is_strict_step0_headless_contract(RTConfig);
end

function screenFcn = local_screen_fcn(RTConfig)
% Resolve real Screen or the explicit headless command-compatible hook.
if nf_is_strict_step0_headless_contract(RTConfig)
    screenFcn = local_get_nested(RTConfig, ...
        {'DevelopmentSession','TestHooks','ScreenFcn'}, []);
else
    screenFcn = @Screen;
end
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

function value = local_get_nested_numeric(S, path, defaultValue)
% Read nested numeric content with a fallback.
value = local_get_nested(S, path, defaultValue);
if ~isnumeric(value)
    value = defaultValue;
end
end

function value = local_get_nested(S, path, defaultValue)
% Read nested content with a fallback.
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

function color = local_rgb01(colorIn)
% Convert 255-based RGB triplets to MATLAB's unit color scale.
color = double(colorIn(:)');
if any(color > 1)
    color = color ./ 255;
end
color = min(max(color, 0), 1);
end

function color = local_rgb255(colorIn)
% Convert unit RGB triplets to Psychtoolbox's 255-based color units.
color = double(colorIn(:)');
if all(color <= 1)
    color = color .* 255;
end
color = min(max(color, 0), 255);
end
