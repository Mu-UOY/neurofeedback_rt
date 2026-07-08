function Circle = nf_feedback_circle_radius(Measure, RTConfig)
% NF_FEEDBACK_CIRCLE_RADIUS Compute local-circle feedback geometry.
%
% USAGE:  Circle = nf_feedback_circle_radius(Measure, RTConfig)
%
% DESCRIPTION:
%     Maps a selected Measure z-score field to normalized feedback and circle
%     radius metadata. This function does not draw, open figures, or require
%     Psychtoolbox.

%% ===== INITIALIZE OUTPUT =====
% Output shape is stable even when the runtime value is invalid.
circleConfig = local_get_circle_config(RTConfig);
Circle = local_empty_circle(circleConfig.MaxRadiusPx);

%% ===== VALIDATE MAP SOURCE =====
% Missing Measure fields are config/schema bugs; nonfinite values are runtime data.
if ~isfield(RTConfig, 'Feedback') || ~isfield(RTConfig.Feedback, 'MapSource') || ...
        isempty(RTConfig.Feedback.MapSource)
    error('RTConfig.Feedback.MapSource must be a valid Measure field.');
end
mapSource = char(RTConfig.Feedback.MapSource);
allowedMapSources = {'ZSmoothed','ZClipped','ZRaw'};
if ~ismember(mapSource, allowedMapSources) || ~isfield(Measure, mapSource)
    error('RTConfig.Feedback.MapSource must be a valid Measure field.');
end

%% ===== HANDLE INVALID RUNTIME VALUES =====
% Invalid windows and nonfinite z-scores do not produce feedback geometry.
if ~isfield(Measure, 'IsValid') || ~Measure.IsValid
    Circle.Message = 'Measure is invalid.';
    return;
end

z = Measure.(mapSource);
if ~isnumeric(z) || isempty(z) || ~isfinite(z(1))
    Circle.Message = sprintf('Measure.%s is nonfinite.', mapSource);
    return;
end
z = double(z(1));

%% ===== MAP Z-SCORE TO RADIUS =====
% Clamp z before converting to normalized feedback in [0, 1].
zClamped = min(max(z, circleConfig.ZMin), circleConfig.ZMax);
u = (zClamped - circleConfig.ZMin) ./ (circleConfig.ZMax - circleConfig.ZMin);

if circleConfig.UseAreaProportionalMapping
    radius = circleConfig.MinRadiusPx + sqrt(u) .* ...
        (circleConfig.MaxRadiusPx - circleConfig.MinRadiusPx);
else
    radius = circleConfig.MinRadiusPx + u .* ...
        (circleConfig.MaxRadiusPx - circleConfig.MinRadiusPx);
end

Circle.ZDisplay = zClamped;
Circle.NormalizedFeedback = u;
Circle.TargetRadiusPx = radius;
Circle.DisplayRadiusPx = radius;
Circle.OuterRadiusPx = circleConfig.MaxRadiusPx;
Circle.DisplayType = 'circle';
Circle.IsFinite = true;
Circle.Message = '';

end

function Circle = local_empty_circle(outerRadiusPx)
% Return NaN display geometry while preserving the configured outer radius.
Circle = struct();
Circle.ZDisplay = NaN;
Circle.NormalizedFeedback = NaN;
Circle.TargetRadiusPx = NaN;
Circle.DisplayRadiusPx = NaN;
Circle.OuterRadiusPx = outerRadiusPx;
Circle.DisplayType = 'circle';
Circle.IsFinite = false;
Circle.Message = '';
end

function circleConfig = local_get_circle_config(RTConfig)
% Read and validate local-circle config fields.
if ~isfield(RTConfig, 'Feedback') || ~isfield(RTConfig.Feedback, 'Circle') || ...
        ~isstruct(RTConfig.Feedback.Circle)
    error('RTConfig.Feedback.Circle must be a struct.');
end

circleConfig = RTConfig.Feedback.Circle;

local_require_field(circleConfig, 'ZMin');
local_require_field(circleConfig, 'ZMax');
local_require_field(circleConfig, 'MinRadiusPx');
local_require_field(circleConfig, 'MaxRadiusPx');
local_require_field(circleConfig, 'UseAreaProportionalMapping');
local_require_field(circleConfig, 'VisualAlpha');

if ~local_is_finite_scalar(circleConfig.ZMin)
    error('ZMin must be finite.');
end
if ~local_is_finite_scalar(circleConfig.ZMax) || circleConfig.ZMax <= circleConfig.ZMin
    error('ZMax must be greater than ZMin.');
end
if ~local_is_finite_scalar(circleConfig.MinRadiusPx) || circleConfig.MinRadiusPx < 0
    error('MinRadiusPx must be finite and >= 0.');
end
if ~local_is_finite_scalar(circleConfig.MaxRadiusPx) || ...
        circleConfig.MaxRadiusPx <= circleConfig.MinRadiusPx
    error('MaxRadiusPx must be greater than MinRadiusPx.');
end
if ~islogical(circleConfig.UseAreaProportionalMapping) || ...
        ~isscalar(circleConfig.UseAreaProportionalMapping)
    error('UseAreaProportionalMapping must be scalar logical.');
end
if ~local_is_finite_scalar(circleConfig.VisualAlpha) || ...
        circleConfig.VisualAlpha < 0 || circleConfig.VisualAlpha > 1
    error('VisualAlpha must be finite in [0, 1].');
end
end

function local_require_field(S, fieldName)
% Throw a concise config error for missing circle fields.
if ~isfield(S, fieldName)
    error('RTConfig.Feedback.Circle.%s is required.', fieldName);
end
end

function tf = local_is_finite_scalar(x)
% Check finite numeric scalar without throwing.
tf = isnumeric(x) && isscalar(x) && isfinite(x);
end
