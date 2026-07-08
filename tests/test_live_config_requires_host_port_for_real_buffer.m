function test_live_config_requires_host_port_for_real_buffer()
% TEST_LIVE_CONFIG_REQUIRES_HOST_PORT_FOR_REAL_BUFFER Check explicit settings.

%% ===== REAL BUFFER REQUIRES HOST AND PORT =====
% With no TestBufferFcn, unresolved connection settings must fail clearly.
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;

didError = false;
try
    nf_check_config(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'Host') || contains(ME.message, 'Port'), ...
        'Unexpected real-buffer config error: %s', ME.message);
end
assert(didError, 'Real live buffer config accepted unresolved host/port.');

%% ===== TEST HOOK MAY KEEP HOST AND PORT UNRESOLVED =====
% Automated tests use the explicit test hook instead of real network settings.
RTConfig.Source.FieldTrip.TestBufferFcn = @(varargin) [];
nf_check_config(RTConfig);

end
