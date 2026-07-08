function test_measure_feedback_fields()
% TEST_MEASURE_FEEDBACK_FIELDS Check canonical feedback display Measure fields.

%% ===== CHECK DEFAULT FEEDBACK FIELDS =====
% The RT core creates these fields but does not assign display geometry.
Measure = nf_measure_empty();

assert(isfield(Measure, 'FeedbackValue'), 'FeedbackValue is missing.');
assert(isnan(Measure.FeedbackValue), 'FeedbackValue should default to NaN.');

assert(isfield(Measure, 'FeedbackTargetRadiusPx'), ...
    'FeedbackTargetRadiusPx is missing.');
assert(isfield(Measure, 'FeedbackDisplayRadiusPx'), ...
    'FeedbackDisplayRadiusPx is missing.');
assert(isfield(Measure, 'FeedbackOuterRadiusPx'), ...
    'FeedbackOuterRadiusPx is missing.');
assert(isfield(Measure, 'FeedbackDisplayType'), ...
    'FeedbackDisplayType is missing.');
assert(isfield(Measure, 'FeedbackDisplayTime'), ...
    'FeedbackDisplayTime is missing.');

assert(isnan(Measure.FeedbackTargetRadiusPx), ...
    'FeedbackTargetRadiusPx should default to NaN.');
assert(isnan(Measure.FeedbackDisplayRadiusPx), ...
    'FeedbackDisplayRadiusPx should default to NaN.');
assert(isnan(Measure.FeedbackOuterRadiusPx), ...
    'FeedbackOuterRadiusPx should default to NaN.');
assert(strcmp(Measure.FeedbackDisplayType, ''), ...
    'FeedbackDisplayType should default to empty text.');
assert(isnan(Measure.FeedbackDisplayTime), ...
    'FeedbackDisplayTime should default to NaN.');

nf_measure_check_schema(Measure);

end
