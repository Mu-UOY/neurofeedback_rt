function Measure = nf_feedback_map_to_display(Measure, RTConfig)
% NF_FEEDBACK_MAP_TO_DISPLAY Map Measure fields to display feedback metadata.
%
% USAGE:  Measure = nf_feedback_map_to_display(Measure, RTConfig)
%
% DESCRIPTION:
%     Stores feedback scalar/display metadata without plotting, UI, or
%     external communication.

%% ===== HANDLE DISABLED FEEDBACK =====
% Mode none leaves FeedbackValue unavailable.
if ~isfield(RTConfig, 'Feedback') || ~isfield(RTConfig.Feedback, 'Mode') || ...
        strcmp(RTConfig.Feedback.Mode, 'none')
    Measure.FeedbackValue = NaN;
    return;
end

%% ===== MAP DEBUG VALUE =====
% Debug feedback selects one z-score field and clips it for display.
switch char(RTConfig.Feedback.Mode)
    case 'debug_value'
        mapSource = char(RTConfig.Feedback.MapSource);
        if ~isfield(Measure, mapSource)
            value = NaN;
        else
            value = Measure.(mapSource);
        end
        clipRange = RTConfig.Feedback.ClipRange;
        if isfinite(value)
            value = min(max(value, clipRange(1)), clipRange(2));
        end
        Measure.FeedbackValue = value;

    case {'local_circle','debug_plot'}
        Circle = nf_feedback_circle_radius(Measure, RTConfig);

        % For local_circle, FeedbackValue is normalized u in [0, 1], not a
        % pixel radius. Pixel geometry lives in the radius fields below.
        Measure.FeedbackValue = Circle.NormalizedFeedback;
        Measure.FeedbackTargetRadiusPx = Circle.TargetRadiusPx;
        Measure.FeedbackDisplayRadiusPx = Circle.DisplayRadiusPx;
        Measure.FeedbackOuterRadiusPx = Circle.OuterRadiusPx;
        Measure.FeedbackDisplayType = Circle.DisplayType;
        Measure.FeedbackDisplayTime = NaN;

    otherwise
        error('Unknown feedback mode: %s', char(RTConfig.Feedback.Mode));
end

end
