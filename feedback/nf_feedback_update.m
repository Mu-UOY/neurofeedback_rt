function [Feedback, Measure] = nf_feedback_update(Feedback, Measure, RTConfig)
% NF_FEEDBACK_UPDATE Draw one feedback frame from mapped Measure fields.
%
% USAGE:  [Feedback, Measure] = nf_feedback_update(Feedback, Measure, RTConfig)
%
% DESCRIPTION:
%     Consumes display metadata already written to Measure by
%     nf_feedback_map_to_display. This function does not remap z-scores.

%% ===== HANDLE NO-DISPLAY BACKEND =====
% none/debug_value display states are safe no-ops.
backend = local_get_backend(Feedback);
if strcmp(backend, 'none')
    return;
end

if isempty(Feedback) || ~isstruct(Feedback)
    error('Feedback must be an initialized feedback struct.');
end
if ~isfield(Feedback, 'IsOpen') || ~Feedback.IsOpen
    error('Feedback display is not open.');
end

%% ===== CHECK MAPPED MEASURE FIELDS =====
% Missing fields are structural bugs; NaN radius is a valid runtime state.
requiredFields = {'FeedbackTargetRadiusPx','FeedbackDisplayRadiusPx', ...
    'FeedbackOuterRadiusPx','FeedbackDisplayType'};
for iField = 1:numel(requiredFields)
    if ~isfield(Measure, requiredFields{iField})
        error('Measure.%s is required before feedback display update.', requiredFields{iField});
    end
end

displayType = char(Measure.FeedbackDisplayType);
if ~isempty(displayType) && ~strcmp(displayType, 'circle')
    error('Unsupported feedback display type: %s', displayType);
end

%% ===== DRAW FRAME =====
% A NaN display radius clears to background and optional static elements only.
switch backend
    case 'debug_plot'
        local_draw_debug_plot(Feedback, Measure, RTConfig);

    case 'psychtoolbox'
        local_draw_psychtoolbox(Feedback, Measure, RTConfig);

    otherwise
        error('Unsupported feedback backend: %s', backend);
end

%% ===== RECORD DISPLAY TIMING =====
% Display time reflects the frame update, not z-score mapping.
tNow = local_timestamp();
Measure.FeedbackDisplayTime = tNow;
Feedback.LastTargetRadiusPx = Measure.FeedbackTargetRadiusPx;
Feedback.LastDisplayRadiusPx = Measure.FeedbackDisplayRadiusPx;
Feedback.LastUpdateTime = tNow;

end

function backend = local_get_backend(Feedback)
% Read backend with robust fallbacks.
backend = '';
if isstruct(Feedback) && isfield(Feedback, 'Backend') && ~isempty(Feedback.Backend)
    backend = char(Feedback.Backend);
end
end

function local_draw_debug_plot(Feedback, Measure, RTConfig)
% Draw the circle frame into an existing hidden or visible MATLAB axes.
if ~isfield(Feedback, 'FigureHandle') || ~isgraphics(Feedback.FigureHandle) || ...
        ~isfield(Feedback, 'AxesHandle') || ~isgraphics(Feedback.AxesHandle)
    error('debug_plot feedback backend does not have valid figure/axes handles.');
end

circle = RTConfig.Feedback.Circle;
ax = Feedback.AxesHandle;
maxRadius = circle.MaxRadiusPx;
margin = 1.1 .* maxRadius;
bg = local_rgb01(circle.BackgroundColor);

cla(ax);
set(Feedback.FigureHandle, 'Color', bg);
set(ax, 'Color', bg);
axis(ax, 'equal');
xlim(ax, [-margin margin]);
ylim(ax, [-margin margin]);
axis(ax, 'off');
hold(ax, 'on');

if local_is_true(circle.ShowOuterCircle)
    rOuter = Measure.FeedbackOuterRadiusPx;
    if ~isfinite(rOuter)
        rOuter = maxRadius;
    end
    rectangle(ax, 'Position', [-rOuter -rOuter 2 .* rOuter 2 .* rOuter], ...
        'Curvature', [1 1], 'FaceColor', 'none', ...
        'EdgeColor', local_rgb01(circle.OuterCircleColor), 'LineWidth', 2);
end

r = Measure.FeedbackDisplayRadiusPx;
if isfinite(r)
    rectangle(ax, 'Position', [-r -r 2 .* r 2 .* r], ...
        'Curvature', [1 1], 'FaceColor', local_rgb01(circle.Color), ...
        'EdgeColor', 'none');
end

if local_is_true(circle.ShowFixation)
    fixationHalfWidth = max(3, 0.025 .* maxRadius);
    line(ax, [-fixationHalfWidth fixationHalfWidth], [0 0], ...
        'Color', [1 1 1], 'LineWidth', 1);
    line(ax, [0 0], [-fixationHalfWidth fixationHalfWidth], ...
        'Color', [1 1 1], 'LineWidth', 1);
end
end

function local_draw_psychtoolbox(Feedback, Measure, RTConfig)
% Draw the circle frame with Psychtoolbox.
if ~isfield(Feedback, 'WindowPtr') || isempty(Feedback.WindowPtr)
    error('psychtoolbox feedback backend does not have a valid WindowPtr.');
end

circle = RTConfig.Feedback.Circle;
win = Feedback.WindowPtr;
center = Feedback.CenterPx;

Screen('FillRect', win, local_rgb255(circle.BackgroundColor));

if local_is_true(circle.ShowOuterCircle)
    rOuter = Measure.FeedbackOuterRadiusPx;
    if ~isfinite(rOuter)
        rOuter = circle.MaxRadiusPx;
    end
    Screen('FrameOval', win, local_rgb255(circle.OuterCircleColor), ...
        local_centered_rect(center, rOuter), 2);
end

r = Measure.FeedbackDisplayRadiusPx;
if isfinite(r)
    Screen('FillOval', win, local_rgb255(circle.Color), ...
        local_centered_rect(center, r));
end

if local_is_true(circle.ShowFixation)
    fixationHalfWidth = max(3, 0.025 .* circle.MaxRadiusPx);
    Screen('DrawLine', win, [255 255 255], ...
        center(1) - fixationHalfWidth, center(2), ...
        center(1) + fixationHalfWidth, center(2), 1);
    Screen('DrawLine', win, [255 255 255], ...
        center(1), center(2) - fixationHalfWidth, ...
        center(1), center(2) + fixationHalfWidth, 1);
end

Screen('Flip', win);
end

function rect = local_centered_rect(center, radius)
% Build PTB oval rectangle from center/radius.
rect = [center(1) - radius, center(2) - radius, ...
    center(1) + radius, center(2) + radius];
end

function t = local_timestamp()
% Prefer PTB timing when available, otherwise use MATLAB serial time.
if exist('GetSecs', 'file') ~= 0 || exist('GetSecs', 'builtin') ~= 0
    t = GetSecs();
else
    t = now;
end
end

function tf = local_is_true(value)
% Accept scalar logical/numeric display flags.
tf = (islogical(value) && isscalar(value) && value) || ...
    (isnumeric(value) && isscalar(value) && isfinite(value) && value ~= 0);
end

function color = local_rgb01(colorIn)
% Convert RGB triplets to MATLAB graphics color units.
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
