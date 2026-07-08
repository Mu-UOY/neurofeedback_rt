function test_modes_constants()
% TEST_MODES_CONSTANTS Check centralized Step 3A-0a mode constants.

%% ===== CHECK SOURCE AND SESSION MODES =====
% Step 3A-0a modes should not reintroduce legacy live/spatial names.
Modes = nf_modes();

assert(strcmp(Modes.Session.LiveDiagnostics, 'live_diagnostics'));
assert(strcmp(Modes.Session.LiveChannelCheck, 'live_channel_check'));
assert(strcmp(Modes.Session.LiveChunkSmokeTest, 'live_chunk_smoke_test'));
assert(strcmp(Modes.Session.LiveRTDryRun, 'live_rt_dry_run'));
assert(strcmp(Modes.Session.LiveSelfTest, 'live_self_test'));
assert(strcmp(Modes.Session.LiveResting, 'live_resting'));
assert(strcmp(Modes.Session.LiveTrial, 'live_trial'));

assert(strcmp(Modes.Source.SimulatedOnline, 'simulated_online'));
assert(strcmp(Modes.Source.SimulatedResting, 'simulated_resting'));
assert(strcmp(Modes.Source.SimulatedTrial, 'simulated_trial'));
assert(strcmp(Modes.Source.LiveFieldTrip, 'live_fieldtrip'));
assert(strcmp(Modes.Source.MockLiveBuffer, 'mock_live_buffer'));
assert(~isfield(Modes.Source, 'LiveBrainstorm'), ...
    'Step 3A-0a must not add Modes.Source.LiveBrainstorm.');

%% ===== CHECK PROCESSING MODES =====
% Technical fallback remains a combined_matrix path selected by MatrixSource.
assert(strcmp(Modes.LiveAdapter.BenFieldTrip, 'ben_fieldtrip_buffer'));
assert(strcmp(Modes.LiveAdapter.MockBuffer, 'mock_buffer'));
assert(strcmp(Modes.Filter.IIRSOS, 'iir_sos'));
assert(strcmp(Modes.Spatial.CombinedMatrix, 'combined_matrix'));
assert(strcmp(Modes.Spatial.MatrixSource.Precomputed, 'precomputed'));
assert(strcmp(Modes.Spatial.MatrixSource.ComputeLive, 'compute_live'));
assert(strcmp(Modes.Spatial.MatrixSource.TechnicalFallback, 'technical_fallback'));
assert(strcmp(Modes.Spatial.MatrixSource.TechnicalPlaceholder, 'technical_placeholder'));
assert(~isfield(Modes.Spatial, 'Identity'), ...
    'Step 3A-0a must not add legacy spatial mode constants.');

%% ===== CHECK FEEDBACK AND STOP MODES =====
% Feedback constants are config-only in this step.
assert(strcmp(Modes.Feedback.None, 'none'));
assert(strcmp(Modes.Feedback.DebugValue, 'debug_value'));
assert(strcmp(Modes.Feedback.LocalCircle, 'local_circle'));
assert(strcmp(Modes.Feedback.DebugPlot, 'debug_plot'));
assert(strcmp(Modes.Feedback.ExternalUDP, 'external_udp'));
assert(strcmp(Modes.Feedback.ExternalSerial, 'external_serial'));
assert(strcmp(Modes.Feedback.ExternalParallel, 'external_parallel'));

assert(strcmp(Modes.TrialStop.Manual, 'manual'));
assert(strcmp(Modes.TrialStop.ManualOrSuccess, 'manual_or_success'));
assert(strcmp(Modes.TrialStop.FixedDuration, 'fixed_duration'));
assert(strcmp(Modes.StopReason.HardFailsafe, 'hard_failsafe'));

end
