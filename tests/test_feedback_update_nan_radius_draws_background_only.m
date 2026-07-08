function test_feedback_update_nan_radius_draws_background_only()
% TEST_FEEDBACK_UPDATE_NAN_RADIUS_DRAWS_BACKGROUND_ONLY Check NaN runtime path.

%% ===== INITIALIZE DEBUG PLOT =====
% NaN radius means mapped-but-invalid runtime data, not missing fields.
RTConfig = nf_mock_live_test_config();
Modes = nf_modes();
RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.AllowDebugPlotFallback = true;
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'DisplayMode')
    RTConfig.Analysis.DisplayMode = 'off';
end

Feedback = nf_feedback_init(RTConfig);
cleanupObj = onCleanup(@() nf_feedback_close(Feedback)); %#ok<NASGU>

Measure = nf_measure_empty();
Measure.IsValid = false;
Measure.ZSmoothed = NaN;
Measure = nf_feedback_map_to_display(Measure, RTConfig);

assert(isfield(Measure, 'FeedbackTargetRadiusPx'), ...
    'Mapped Measure is missing FeedbackTargetRadiusPx.');
assert(isnan(Measure.FeedbackTargetRadiusPx), ...
    'Invalid mapped Measure should have NaN target radius.');

[Feedback, Measure] = nf_feedback_update(Feedback, Measure, RTConfig);

assert(isnan(Measure.FeedbackDisplayRadiusPx), ...
    'NaN radius update should preserve NaN display radius.');
assert(isfinite(Measure.FeedbackDisplayTime), ...
    'NaN radius update should still record display time.');
assert(isfinite(Feedback.LastUpdateTime), ...
    'NaN radius update should still record Feedback.LastUpdateTime.');
assert(isgraphics(Feedback.FigureHandle), 'Figure became invalid after NaN update.');
assert(isgraphics(Feedback.AxesHandle), 'Axes became invalid after NaN update.');

end
