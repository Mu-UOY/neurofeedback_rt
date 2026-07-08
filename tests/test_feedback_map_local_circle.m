function test_feedback_map_local_circle()
% TEST_FEEDBACK_MAP_LOCAL_CIRCLE Check local-circle Measure mapping.

%% ===== MAP VALID MEASURE =====
% local_circle stores normalized feedback plus pixel-radius metadata.
RTConfig = nf_mock_live_test_config();
Modes = nf_modes();
RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.MapSource = 'ZSmoothed';

Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.ZSmoothed = 0;

Mapped = nf_feedback_map_to_display(Measure, RTConfig);

minRadius = RTConfig.Feedback.Circle.MinRadiusPx;
maxRadius = RTConfig.Feedback.Circle.MaxRadiusPx;
expectedU = 0.5;
expectedRadius = minRadius + sqrt(expectedU) .* (maxRadius - minRadius);

assert(isfinite(Mapped.FeedbackValue), 'FeedbackValue is not finite.');
assert(isfinite(Mapped.FeedbackTargetRadiusPx), ...
    'FeedbackTargetRadiusPx is not finite.');
assert(isfinite(Mapped.FeedbackDisplayRadiusPx), ...
    'FeedbackDisplayRadiusPx is not finite.');
assert(isfinite(Mapped.FeedbackOuterRadiusPx), ...
    'FeedbackOuterRadiusPx is not finite.');
assert(strcmp(Mapped.FeedbackDisplayType, 'circle'), ...
    'FeedbackDisplayType should be circle.');
assert(isnan(Mapped.FeedbackDisplayTime), ...
    'FeedbackDisplayTime should stay NaN in mapping-only step.');
assert(abs(Mapped.FeedbackValue - expectedU) < 1e-10, ...
    'FeedbackValue should be normalized u, not radius.');
assert(abs(Mapped.FeedbackTargetRadiusPx - expectedRadius) < 1e-10, ...
    'Unexpected target radius.');
assert(Mapped.FeedbackDisplayRadiusPx == Mapped.FeedbackTargetRadiusPx, ...
    'VisualAlpha=1 should not add display smoothing.');

%% ===== MAP INVALID AND NONFINITE MEASURES =====
% Invalid windows should not crash or produce display geometry.
Invalid = Measure;
Invalid.IsValid = false;
MappedInvalid = nf_feedback_map_to_display(Invalid, RTConfig);
assert(isnan(MappedInvalid.FeedbackValue), 'Invalid Measure produced FeedbackValue.');
assert(isnan(MappedInvalid.FeedbackTargetRadiusPx), ...
    'Invalid Measure produced target radius.');

Nonfinite = Measure;
Nonfinite.ZSmoothed = NaN;
MappedNonfinite = nf_feedback_map_to_display(Nonfinite, RTConfig);
assert(isnan(MappedNonfinite.FeedbackValue), 'NaN z produced FeedbackValue.');
assert(isnan(MappedNonfinite.FeedbackTargetRadiusPx), ...
    'NaN z produced target radius.');

end
