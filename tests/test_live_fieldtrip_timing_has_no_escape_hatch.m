function test_live_fieldtrip_timing_has_no_escape_hatch()
% TEST_LIVE_FIELDTRIP_TIMING_HAS_NO_ESCAPE_HATCH Check live timing strictness.

%% ===== CHECK LIVE TIMING ESCAPE IS NOT HONORED =====
% AllowNonLiveTimingInMock must never relax live FieldTrip timing.
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Session.Mode = Modes.Session.LiveDiagnostics;
RTConfig.Fs = 1000;
RTConfig.Debug.AllowNonLiveTimingInMock = true;
RTConfig.Debug.Verbose = false;

didError = false;
try
    nf_finalize_config(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, '2400'), ...
        'Unexpected live timing error: %s', ME.message);
end
assert(didError, 'Live FieldTrip accepted non-live timing.');

end
