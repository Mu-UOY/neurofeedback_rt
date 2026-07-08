function test_live_requires_psychtoolbox_unless_override()
% TEST_LIVE_REQUIRES_PSYCHTOOLBOX_UNLESS_OVERRIDE Check live backend discipline.

%% ===== LIVE FIELDTRIP REQUIRES PTB WHEN CONFIGURED =====
% Actual PTB open-path validation is reserved for manual display-room checks.
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Source.Mode = Modes.Source.LiveFieldTrip;
RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.RequirePsychtoolboxForLive = true;
RTConfig.Feedback.AllowDebugPlotFallback = true;

hasPTB = exist('Screen', 'file') ~= 0 || exist('Screen', 'builtin') ~= 0;
if hasPTB
    fprintf('[SKIP] Psychtoolbox detected; not opening live PTB window in automated test.\n');
else
    didError = false;
    try
        nf_feedback_init(RTConfig);
    catch ME
        didError = true;
        assert(contains(ME.message, 'Psychtoolbox'), ...
            'Unexpected missing-PTB error: %s', ME.message);
    end
    assert(didError, 'live_fieldtrip silently fell back without PTB.');
end

%% ===== LIVE OVERRIDE MAY USE DEBUG PLOT =====
% This is an explicit local override and still uses hidden figures.
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
RTConfig.Feedback.AllowDebugPlotFallback = true;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'DisplayMode')
    RTConfig.Analysis.DisplayMode = 'off';
end

Feedback = nf_feedback_init(RTConfig);
cleanupObj = onCleanup(@() nf_feedback_close(Feedback)); %#ok<NASGU>
assert(strcmp(Feedback.Backend, 'debug_plot'), ...
    'Live override did not use explicit debug_plot fallback.');
assert(Feedback.UsesPsychtoolbox == false, ...
    'Live override should not require Psychtoolbox.');
Feedback = nf_feedback_close(Feedback);

end
