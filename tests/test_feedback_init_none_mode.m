function test_feedback_init_none_mode()
% TEST_FEEDBACK_INIT_NONE_MODE Check no-display feedback initialization.

%% ===== INITIALIZE NONE MODE =====
% none mode should never open a display surface.
RTConfig = nf_mock_live_test_config();
Modes = nf_modes();
RTConfig.Feedback.Mode = Modes.Feedback.None;

Feedback = nf_feedback_init(RTConfig);

assert(strcmp(Feedback.Backend, 'none'), 'none mode should use Backend=none.');
assert(Feedback.IsOpen == false, 'none mode should not open a display.');
assert(Feedback.UsesPsychtoolbox == false, 'none mode should not use PTB.');
assert(Feedback.UsesDebugPlot == false, 'none mode should not use debug_plot.');

Feedback = nf_feedback_close(Feedback);
assert(Feedback.IsOpen == false, 'Closed none Feedback should stay closed.');

%% ===== INITIALIZE DEBUG VALUE MODE =====
% debug_value is scalar-only and should not open a circle display.
RTConfig.Feedback.Mode = Modes.Feedback.DebugValue;
Feedback = nf_feedback_init(RTConfig);
assert(strcmp(Feedback.Backend, 'none'), 'debug_value should use Backend=none.');
assert(Feedback.IsOpen == false, 'debug_value should not open a display.');
Feedback = nf_feedback_close(Feedback);
assert(Feedback.IsOpen == false, 'Closed debug_value Feedback should stay closed.');

end
