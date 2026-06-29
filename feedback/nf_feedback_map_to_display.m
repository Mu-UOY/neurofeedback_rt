function Measure = nf_feedback_map_to_display(Measure, RTConfig)
% NF_FEEDBACK_MAP_TO_DISPLAY Map z-score fields to debug feedback value.
%
% USAGE:  Measure = nf_feedback_map_to_display(Measure, RTConfig)
%
% DESCRIPTION:
%     Stores a clipped scalar FeedbackValue without plotting, UI, or external
%     communication.

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

    otherwise
        error('Unknown feedback mode: %s', char(RTConfig.Feedback.Mode));
end

end
