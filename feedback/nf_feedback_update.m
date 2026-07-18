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
Modes = nf_modes();
backend = local_get_backend(Feedback);
if strcmp(backend, Modes.FeedbackBackend.None)
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
if ~isempty(displayType) && ~strcmp(displayType, Modes.FeedbackDisplay.Circle)
    error('Unsupported feedback display type: %s', displayType);
end

%% ===== DRAW FRAME =====
% A NaN display radius clears to background and optional static elements only.
switch backend
    case Modes.FeedbackBackend.DebugPlot
        local_draw_debug_plot(Feedback, Measure, RTConfig);

    case Modes.FeedbackBackend.Psychtoolbox
        [Feedback, flip] = local_draw_psychtoolbox(Feedback, Measure, RTConfig);
        if isempty(Feedback.FlipAudit)
            Feedback.FlipAudit = flip;
        else
            Feedback.FlipAudit(end + 1) = flip;
        end

    otherwise
        error('Unsupported feedback backend: %s', backend);
end

%% ===== RECORD DISPLAY TIMING =====
% Display time reflects the frame update, not z-score mapping.
tNow = local_timestamp(Feedback);
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
margin = circle.DebugAxesMarginScale .* maxRadius;
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
        'EdgeColor', local_rgb01(circle.OuterCircleColor), ...
        'LineWidth', circle.OuterCircleLineWidthPx);
end

r = Measure.FeedbackDisplayRadiusPx;
if isfinite(r)
    rectangle(ax, 'Position', [-r -r 2 .* r 2 .* r], ...
        'Curvature', [1 1], 'FaceColor', local_rgb01(circle.Color), ...
        'EdgeColor', 'none');
end

if local_is_true(circle.ShowFixation)
    fixationHalfWidth = max(circle.FixationMinHalfWidthPx, ...
        circle.FixationHalfWidthFraction .* maxRadius);
    line(ax, [-fixationHalfWidth fixationHalfWidth], [0 0], ...
        'Color', [1 1 1], 'LineWidth', circle.FixationLineWidthPx);
    line(ax, [0 0], [-fixationHalfWidth fixationHalfWidth], ...
        'Color', [1 1 1], 'LineWidth', circle.FixationLineWidthPx);
end
end

function [Feedback, Flip] = local_draw_psychtoolbox(Feedback, Measure, RTConfig)
% Draw the circle frame with Psychtoolbox.
if ~isfield(Feedback, 'WindowPtr') || isempty(Feedback.WindowPtr)
    error('psychtoolbox feedback backend does not have a valid WindowPtr.');
end

circle = RTConfig.Feedback.Circle;
win = Feedback.WindowPtr;
center = Feedback.CenterPx;
screenFcn = Feedback.ScreenFcn;

screenFcn('FillRect', win, local_rgb255(circle.BackgroundColor));

if local_is_true(circle.ShowOuterCircle)
    rOuter = Measure.FeedbackOuterRadiusPx;
    if ~isfinite(rOuter)
        rOuter = circle.MaxRadiusPx;
    end
    screenFcn('FrameOval', win, local_rgb255(circle.OuterCircleColor), ...
        local_centered_rect(center, rOuter), circle.OuterCircleLineWidthPx);
end

r = Measure.FeedbackDisplayRadiusPx;
if isfinite(r)
    screenFcn('FillOval', win, local_rgb255(circle.Color), ...
        local_centered_rect(center, r));
end

if local_is_true(circle.ShowFixation)
    fixationHalfWidth = max(circle.FixationMinHalfWidthPx, ...
        circle.FixationHalfWidthFraction .* circle.MaxRadiusPx);
    % Convert unit RGB white to Psychtoolbox's 255-based color units.
    fixationColor = local_rgb255([1 1 1]);
    screenFcn('DrawLine', win, fixationColor, ...
        center(1) - fixationHalfWidth, center(2), ...
        center(1) + fixationHalfWidth, center(2), circle.FixationLineWidthPx);
    screenFcn('DrawLine', win, fixationColor, ...
        center(1), center(2) - fixationHalfWidth, ...
        center(1), center(2) + fixationHalfWidth, circle.FixationLineWidthPx);
end

requestIssuedAt = local_timestamp(Feedback);
[vbl, onset, flipTimestamp, missed, beamPosition] = ...
    screenFcn('Flip', win, Feedback.FlipWhen);
if ~local_is_finite_real_numeric_scalar(missed)
    error('neurofeedback:developmentFeedbackAuditInvalid', ...
        ['Psychtoolbox missed deadline estimate must be a finite, real, ' ...
        'numeric scalar.']);
end
Flip = struct();
Flip.RequestIssuedAt = requestIssuedAt;
Flip.RequestedWhen = Feedback.FlipWhen;
Flip.VBLTimestamp = vbl;
Flip.StimulusOnsetTime = onset;
Flip.FlipTimestamp = flipTimestamp;
Flip.Missed = missed;
Flip.DeadlineMissed = missed > 0;
Flip.BeamPosition = beamPosition;
Flip.MeasureTime = local_field(Measure, 'Time', NaN);
Flip.WindowStartSample = local_field(Measure, 'WindowStartSample', NaN);
Flip.WindowEndSample = local_field(Measure, 'WindowEndSample', NaN);
Flip.ValidMeasureIndex = local_field(Measure, 'ValidMeasureIndex', NaN);
end

function rect = local_centered_rect(center, radius)
% Build PTB oval rectangle from center/radius.
rect = [center(1) - radius, center(2) - radius, ...
    center(1) + radius, center(2) + radius];
end

function t = local_timestamp(Feedback)
% Prefer PTB timing when available, otherwise use MATLAB serial time.
if isstruct(Feedback) && isfield(Feedback, 'TimeFcn') && ...
        isa(Feedback.TimeFcn, 'function_handle')
    t = double(Feedback.TimeFcn());
elseif exist('GetSecs', 'file') ~= 0 || exist('GetSecs', 'builtin') ~= 0
    t = GetSecs();
else
    t = now;
end
end

function value = local_field(S, fieldName, defaultValue)
% Read an optional scalar audit field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    value = S.(fieldName);
end
end

function tf = local_is_true(value)
% Accept scalar logical/numeric display flags.
tf = (islogical(value) && isscalar(value) && value) || ...
    (isnumeric(value) && isscalar(value) && isfinite(value) && value ~= 0);
end

function tf = local_is_finite_real_numeric_scalar(value)
% Psychtoolbox timing estimates are signed real-valued seconds.
tf = isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value);
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
% Convert RGB triplets to PTB's 255-based color units.
color = double(colorIn(:)');
if all(color <= 1)
    color = color .* 255;
end
color = min(max(color, 0), 255);
end
