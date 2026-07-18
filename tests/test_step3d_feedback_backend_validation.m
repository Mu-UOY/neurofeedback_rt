function test_step3d_feedback_backend_validation()
% TEST_STEP3D_FEEDBACK_BACKEND_VALIDATION Check backend consistency rules.

Modes = nf_modes();
[RTConfig, tempRoot] = nf_test_live_self_test_config();
cleanupObj = onCleanup(@() local_cleanup(tempRoot));

RTConfig.Feedback.Mode = Modes.Feedback.None;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.Psychtoolbox;
nf_check_config(RTConfig);

RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.None;
didError = false;
try
    nf_check_config(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'LocalCircle'), 'Unexpected backend error: %s', ME.message);
end
assert(didError, 'LocalCircle+Backend=None was accepted.');

RTConfig.Feedback.Backend = Modes.FeedbackBackend.DebugPlot;
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
nf_check_config(RTConfig);

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
