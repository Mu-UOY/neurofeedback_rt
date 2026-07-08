function Modes = nf_modes()
% NF_MODES Centralized mode names for session/source/filter/spatial/feedback.

Modes.Session.LiveDiagnostics = 'live_diagnostics';
Modes.Session.LiveChannelCheck = 'live_channel_check';
Modes.Session.LiveChunkSmokeTest = 'live_chunk_smoke_test';
Modes.Session.LiveRTDryRun = 'live_rt_dry_run';
Modes.Session.LiveSelfTest = 'live_self_test';
Modes.Session.LiveResting = 'live_resting';
Modes.Session.LiveTrial = 'live_trial';

Modes.Source.SimulatedOnline = 'simulated_online';
Modes.Source.SimulatedResting = 'simulated_resting';
Modes.Source.SimulatedTrial = 'simulated_trial';
Modes.Source.LiveFieldTrip = 'live_fieldtrip';
Modes.Source.MockLiveBuffer = 'mock_live_buffer';

Modes.LiveAdapter.BenFieldTrip = 'ben_fieldtrip_buffer';
Modes.LiveAdapter.MockBuffer = 'mock_buffer';

Modes.Filter.IIRSOS = 'iir_sos';

Modes.Spatial.CombinedMatrix = 'combined_matrix';

Modes.Spatial.MatrixSource.ComputeLive = 'compute_live';
Modes.Spatial.MatrixSource.Precomputed = 'precomputed';
Modes.Spatial.MatrixSource.TechnicalFallback = 'technical_fallback';
Modes.Spatial.MatrixSource.TechnicalPlaceholder = 'technical_placeholder';

Modes.Feedback.None = 'none';
Modes.Feedback.DebugValue = 'debug_value';
Modes.Feedback.LocalCircle = 'local_circle';
Modes.Feedback.DebugPlot = 'debug_plot';
Modes.Feedback.ExternalUDP = 'external_udp';
Modes.Feedback.ExternalSerial = 'external_serial';
Modes.Feedback.ExternalParallel = 'external_parallel';

Modes.TrialStop.Manual = 'manual';
Modes.TrialStop.ManualOrSuccess = 'manual_or_success';
Modes.TrialStop.FixedDuration = 'fixed_duration';

Modes.StopReason.Manual = 'manual';
Modes.StopReason.Success = 'success';
Modes.StopReason.HardFailsafe = 'hard_failsafe';
Modes.StopReason.Error = 'error';
Modes.StopReason.CompletedUnknown = 'completed_unknown';

end
