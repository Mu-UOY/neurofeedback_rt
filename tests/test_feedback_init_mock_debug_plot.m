function test_feedback_init_mock_debug_plot()
% TEST_FEEDBACK_INIT_MOCK_DEBUG_PLOT Check mock/local hidden debug_plot init.

%% ===== INITIALIZE MOCK DEBUG PLOT =====
% Mock-live tests use hidden MATLAB figures and do not require Psychtoolbox.
RTConfig = nf_mock_live_test_config();
Modes = nf_modes();
RTConfig.Source.Mode = Modes.Source.MockLiveBuffer;
RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.AllowDebugPlotFallback = true;
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'DisplayMode')
    RTConfig.Analysis.DisplayMode = 'off';
end

Feedback = nf_feedback_init(RTConfig);
cleanupObj = onCleanup(@() nf_feedback_close(Feedback)); %#ok<NASGU>

assert(strcmp(Feedback.Backend, 'debug_plot'), ...
    'Mock local_circle should use debug_plot backend.');
assert(Feedback.IsOpen == true, 'debug_plot backend should be open.');
assert(Feedback.UsesDebugPlot == true, 'debug_plot flag was not set.');
assert(Feedback.UsesPsychtoolbox == false, 'debug_plot should not use PTB.');
assert(isgraphics(Feedback.FigureHandle), 'debug_plot figure is invalid.');
assert(isgraphics(Feedback.AxesHandle), 'debug_plot axes are invalid.');

Feedback = nf_feedback_close(Feedback);
assert(Feedback.IsOpen == false, 'Feedback did not close.');
assert(isempty(Feedback.FigureHandle), 'FigureHandle was not nulled.');
assert(isempty(Feedback.AxesHandle), 'AxesHandle was not nulled.');

end
