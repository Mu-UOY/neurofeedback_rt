function test_measure_schema()
% TEST_MEASURE_SCHEMA Validate canonical Measure schema checks.
%
% USAGE:  test_measure_schema()
%
% DESCRIPTION:
%     Checks that the canonical empty Measure passes schema validation and
%     that removing a required field is rejected.

%% ===== CHECK VALID SCHEMA =====
% A freshly created Measure should pass unchanged.
Measure = nf_measure_empty();
Measure = nf_measure_check_schema(Measure);
assert(isfield(Measure, 'Power'), 'Schema check changed the Measure unexpectedly.');
assert(isfield(Measure, 'FeedbackTargetRadiusPx'), ...
    'Measure schema missing FeedbackTargetRadiusPx.');
assert(isfield(Measure, 'FeedbackDisplayType'), ...
    'Measure schema missing FeedbackDisplayType.');

%% ===== CHECK MISSING FIELD ERROR =====
% Removing a required field should make schema validation fail.
badMeasure = rmfield(Measure, 'Power');
didError = false;
try
    nf_measure_check_schema(badMeasure);
catch
    didError = true;
end
assert(didError, 'Schema check did not reject a missing required field.');

end
