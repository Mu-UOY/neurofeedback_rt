function test_feedback_update_local_circle_debug_plot()
% TEST_FEEDBACK_UPDATE_LOCAL_CIRCLE_DEBUG_PLOT Check one debug_plot frame update.

%% ===== INITIALIZE DEBUG PLOT =====
% Display update consumes mapped fields produced outside the RT core.
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

[Feedback, Measure] = nf_feedback_update(Feedback, Measure, RTConfig);

assert(isfinite(Measure.FeedbackTargetRadiusPx), 'Target radius is not finite.');
assert(isfinite(Measure.FeedbackDisplayRadiusPx), 'Display radius is not finite.');
assert(isfinite(Measure.FeedbackDisplayTime), 'Display time was not recorded.');
assert(isfinite(Feedback.LastTargetRadiusPx), 'Feedback target radius was not recorded.');
assert(isfinite(Feedback.LastDisplayRadiusPx), 'Feedback display radius was not recorded.');
assert(isfinite(Feedback.LastUpdateTime), 'Feedback update time was not recorded.');

%% ===== CHECK MISSING MAPPED FIELD ERROR =====
% Structurally missing mapped fields should not be treated as runtime NaNs.
badMeasure = rmfield(Measure, 'FeedbackTargetRadiusPx');
didError = false;
try
    nf_feedback_update(Feedback, badMeasure, RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'FeedbackTargetRadiusPx'), ...
        'Unexpected missing mapped-field error: %s', ME.message);
end
assert(didError, 'Missing mapped field did not error.');

end
