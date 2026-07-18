function nf_development_maybe_inject_failure(RTConfig, failurePoint, occurrence)
% NF_DEVELOPMENT_MAYBE_INJECT_FAILURE Activate a scoped Step 0 test hook.

Modes = nf_modes();
if ~nf_is_strict_step0_headless_contract(RTConfig)
    return;
end
configuredPoint = RTConfig.DevelopmentSession.TestHooks.FailurePoint;
configuredOccurrence = RTConfig.DevelopmentSession.TestHooks.FailureOccurrence;
if strcmp(configuredPoint, Modes.DevelopmentFailure.None)
    return;
end
if strcmp(char(failurePoint), char(configuredPoint)) && occurrence == configuredOccurrence
    error(['neurofeedback:developmentInjected:' char(failurePoint)], ...
        'Injected Step 0 development failure at %s occurrence %d.', ...
        char(failurePoint), occurrence);
end

end
