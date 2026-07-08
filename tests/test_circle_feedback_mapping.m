function test_circle_feedback_mapping()
% TEST_CIRCLE_FEEDBACK_MAPPING Check local-circle radius computation.

%% ===== CHECK AREA-PROPORTIONAL MAPPING =====
% Default mock-live config maps ZSmoothed in [-3, 3] to [20, 220] px.
RTConfig = nf_mock_live_test_config();
RTConfig.Debug.Verbose = false;

zMin = RTConfig.Feedback.Circle.ZMin;
zMax = RTConfig.Feedback.Circle.ZMax;
minRadius = RTConfig.Feedback.Circle.MinRadiusPx;
maxRadius = RTConfig.Feedback.Circle.MaxRadiusPx;
tol = 1e-10;

Circle = local_circle_for_z(RTConfig, zMin - 10);
assert(abs(Circle.TargetRadiusPx - minRadius) < tol, ...
    'Below ZMin did not clamp to min radius.');
assert(Circle.NormalizedFeedback == 0, 'Below ZMin did not clamp u to 0.');

Circle = local_circle_for_z(RTConfig, zMin);
assert(abs(Circle.TargetRadiusPx - minRadius) < tol, ...
    'ZMin did not map to min radius.');

Circle = local_circle_for_z(RTConfig, 0);
expectedRadius = minRadius + sqrt(0.5) .* (maxRadius - minRadius);
assert(abs(Circle.TargetRadiusPx - expectedRadius) < tol, ...
    'Midpoint did not use area-proportional mapping.');
assert(abs(Circle.NormalizedFeedback - 0.5) < tol, ...
    'Midpoint normalized feedback is incorrect.');

Circle = local_circle_for_z(RTConfig, zMax);
assert(abs(Circle.TargetRadiusPx - maxRadius) < tol, ...
    'ZMax did not map to max radius.');

Circle = local_circle_for_z(RTConfig, zMax + 10);
assert(abs(Circle.TargetRadiusPx - maxRadius) < tol, ...
    'Above ZMax did not clamp to max radius.');
assert(Circle.NormalizedFeedback == 1, 'Above ZMax did not clamp u to 1.');
assert(Circle.OuterRadiusPx == maxRadius, 'Outer radius is not MaxRadiusPx.');

Circle = local_circle_for_z(RTConfig, NaN);
assert(~Circle.IsFinite, 'NaN z should not be finite feedback.');
assert(isnan(Circle.TargetRadiusPx), 'NaN z should produce NaN target radius.');
assert(isnan(Circle.NormalizedFeedback), 'NaN z should produce NaN normalized feedback.');

%% ===== CHECK LINEAR MAPPING =====
% Linear mapping should use u directly instead of sqrt(u).
RTConfig.Feedback.Circle.UseAreaProportionalMapping = false;
Circle = local_circle_for_z(RTConfig, 0);
expectedRadius = minRadius + 0.5 .* (maxRadius - minRadius);
assert(abs(Circle.TargetRadiusPx - expectedRadius) < tol, ...
    'Midpoint did not use linear mapping.');

%% ===== CHECK MAP SOURCE FLEXIBILITY =====
% The helper should respect Feedback.MapSource rather than hard-coding ZSmoothed.
RTConfig.Feedback.MapSource = 'ZRaw';
Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.ZRaw = 1.0;
Measure.ZSmoothed = -3.0;

Circle = nf_feedback_circle_radius(Measure, RTConfig);
expectedU = (1.0 - zMin) ./ (zMax - zMin);
assert(abs(Circle.NormalizedFeedback - expectedU) < tol, ...
    'Circle mapping did not use ZRaw MapSource.');

%% ===== CHECK BAD MAP SOURCE =====
% A misspelled source is a config/schema bug and should throw clearly.
RTConfig.Feedback.MapSource = 'ZSmooth';
didError = false;
try
    nf_feedback_circle_radius(Measure, RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'MapSource'), ...
        'Unexpected bad MapSource error: %s', ME.message);
end
assert(didError, 'Bad MapSource was accepted.');

end

function Circle = local_circle_for_z(RTConfig, zValue)
% Build one valid Measure and map it to circle geometry.
Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.ZSmoothed = zValue;
Circle = nf_feedback_circle_radius(Measure, RTConfig);
end
