function test_feedback_close_safe()
% TEST_FEEDBACK_CLOSE_SAFE Check robust display cleanup.

%% ===== CLOSE EMPTY AND PARTIAL INPUTS =====
% Cleanup should tolerate empty, partial, and already closed structs.
nf_feedback_close([]);
Feedback = nf_feedback_close(struct());
assert(isstruct(Feedback), 'Closing struct() should return a struct.');
assert(isfield(Feedback, 'IsOpen') && Feedback.IsOpen == false, ...
    'Partial close should mark IsOpen=false.');

Feedback = nf_feedback_close(Feedback);
assert(Feedback.IsOpen == false, 'Double-close of partial Feedback failed.');

%% ===== CLOSE DEBUG PLOT TWICE =====
% Figure handles should be invalidated and nulled after close.
RTConfig = nf_mock_live_test_config();
Modes = nf_modes();
RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.AllowDebugPlotFallback = true;
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'DisplayMode')
    RTConfig.Analysis.DisplayMode = 'off';
end

Feedback = nf_feedback_init(RTConfig);
fig = Feedback.FigureHandle;
assert(isgraphics(fig), 'debug_plot figure was not created.');

Feedback = nf_feedback_close(Feedback);
assert(Feedback.IsOpen == false, 'Feedback did not close.');
assert(~isgraphics(fig), 'debug_plot figure is still open after close.');
assert(isempty(Feedback.FigureHandle), 'FigureHandle was not nulled.');
assert(isempty(Feedback.AxesHandle), 'AxesHandle was not nulled.');
assert(isempty(Feedback.WindowPtr), 'WindowPtr was not nulled.');

Feedback = nf_feedback_close(Feedback);
assert(Feedback.IsOpen == false, 'Second close reopened Feedback.');

end
