function test_feedback_visual_alpha_one_no_extra_smoothing()
% TEST_FEEDBACK_VISUAL_ALPHA_ONE_NO_EXTRA_SMOOTHING Check radius passthrough.

%% ===== CHECK VISUAL ALPHA ONE =====
% ZSmoothed is already the temporal smoothing source for display feedback.
RTConfig = nf_mock_live_test_config();
RTConfig.Feedback.Circle.VisualAlpha = 1.0;

Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.ZSmoothed = 1.25;

Circle = nf_feedback_circle_radius(Measure, RTConfig);
assert(Circle.DisplayRadiusPx == Circle.TargetRadiusPx, ...
    'VisualAlpha=1 should make display radius equal target radius.');

Mapped = nf_feedback_map_to_display(Measure, RTConfig);
assert(Mapped.FeedbackDisplayRadiusPx == Mapped.FeedbackTargetRadiusPx, ...
    'Mapped Measure added extra display smoothing.');

end
