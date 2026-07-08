function test_mock_live_uses_same_timing_assertions_as_live()
% TEST_MOCK_LIVE_USES_SAME_TIMING_ASSERTIONS_AS_LIVE Check mock timing.

%% ===== CHECK MOCK-LIVE STRICT DEFAULT =====
% Mock-live uses live timing unless the explicit mock-only escape hatch is set.
RTConfig = nf_mock_live_test_config();
RTConfig.Fs = 1000;
RTConfig.Internal.IsFinalized = false;
RTConfig.Debug.AllowNonLiveTimingInMock = false;
RTConfig.Debug.Verbose = false;

didError = false;
try
    nf_finalize_config(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, '2400'), ...
        'Unexpected mock-live timing error: %s', ME.message);
end
assert(didError, 'Mock-live accepted wrong timing by default.');

%% ===== CHECK MOCK-LIVE ESCAPE HATCH =====
% The escape hatch applies only to MockLiveBuffer.
RTConfig.Debug.AllowNonLiveTimingInMock = true;
RTConfig = nf_finalize_config(RTConfig);
assert(RTConfig.Fs == 1000, 'Mock timing escape did not preserve Fs.');
assert(RTConfig.ChunkSamples == round(RTConfig.ChunkSeconds * RTConfig.Fs), ...
    'Mock timing escape did not derive ChunkSamples.');

end
