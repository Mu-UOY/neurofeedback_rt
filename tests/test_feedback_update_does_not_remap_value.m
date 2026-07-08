function test_feedback_update_does_not_remap_value()
% TEST_FEEDBACK_UPDATE_DOES_NOT_REMAP_VALUE Check display consumes mapped fields.

%% ===== INITIALIZE AND MAP MEASURE =====
% Update should not call mapping helpers or recompute from changed z-scores.
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
Measure.IsValid = true;
Measure.ZSmoothed = 0;
Measure = nf_feedback_map_to_display(Measure, RTConfig);

originalFeedbackValue = Measure.FeedbackValue;
originalTargetRadius = Measure.FeedbackTargetRadiusPx;
Measure.ZSmoothed = 999;

[Feedback, Measure] = nf_feedback_update(Feedback, Measure, RTConfig); %#ok<ASGLU>

assert(Measure.FeedbackValue == originalFeedbackValue, ...
    'Feedback update recomputed FeedbackValue.');
assert(Measure.FeedbackTargetRadiusPx == originalTargetRadius, ...
    'Feedback update recomputed target radius.');

end
