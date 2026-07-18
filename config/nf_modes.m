function Modes = nf_modes()
% NF_MODES Centralized mode names for session/source/filter/spatial/feedback.

Modes.Session.LiveDiagnostics = 'live_diagnostics';
Modes.Session.LiveChannelCheck = 'live_channel_check';
Modes.Session.LiveChunkSmokeTest = 'live_chunk_smoke_test';
Modes.Session.LiveRTDryRun = 'live_rt_dry_run';
Modes.Session.LiveSelfTest = 'live_self_test';
Modes.Session.LiveResting = 'live_resting';
Modes.Session.LiveTrial = 'live_trial';
Modes.Session.DevelopmentFullChain = 'development_full_chain';

Modes.Phase.Resting = 'resting';
Modes.Phase.Transition = 'transition';
Modes.Phase.Trial = 'trial';

Modes.PhaseRunnerOwner.Internal = 'internal';
Modes.PhaseRunnerOwner.External = 'external';

Modes.DevelopmentInput.MEGPlusMEGReference = 'meg_plus_meg_reference';

Modes.Source.SimulatedOnline = 'simulated_online';
Modes.Source.SimulatedResting = 'simulated_resting';
Modes.Source.SimulatedTrial = 'simulated_trial';
Modes.Source.LiveFieldTrip = 'live_fieldtrip';
Modes.Source.MockLiveBuffer = 'mock_live_buffer';

Modes.LiveAdapter.BenFieldTrip = 'ben_fieldtrip_buffer';
Modes.LiveAdapter.MockBuffer = 'mock_buffer';

Modes.Filter.IIRSOS = 'iir_sos';

Modes.Spatial.CombinedMatrix = 'combined_matrix';
Modes.Spatial.FallbackType.RepresentativeDense = 'representative_dense';

Modes.MatrixOrientation.OutputByInput = 'output_by_input';

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

Modes.FeedbackBackend.None = 'none';
Modes.FeedbackBackend.Psychtoolbox = 'psychtoolbox';
Modes.FeedbackBackend.DebugPlot = 'debug_plot';
Modes.FeedbackBackend.DebugValue = 'debug_value';
Modes.FeedbackDisplay.Circle = 'circle';

Modes.DevelopmentDisplay.RealPsychtoolbox = 'real_psychtoolbox';
Modes.DevelopmentDisplay.HeadlessPsychtoolboxTest = 'headless_psychtoolbox_test';
Modes.ScreenSelection.HighestIndex = 'highest_index';

Modes.DevelopmentStatus.Pass = 'development_pass';
Modes.DevelopmentStatus.Fail = 'development_fail';
Modes.DevelopmentStatus.Partial = 'development_partial';

Modes.TrialStop.Manual = 'manual';
Modes.TrialStop.ManualOrSuccess = 'manual_or_success';
Modes.TrialStop.FixedDuration = 'fixed_duration';

Modes.StopReason.Manual = 'manual';
Modes.StopReason.Success = 'success';
Modes.StopReason.HardFailsafe = 'hard_failsafe';
Modes.StopReason.Error = 'error';
Modes.StopReason.Timeout = 'timeout';
Modes.StopReason.StopFile = 'stop_file';
Modes.StopReason.CompletedUnknown = 'completed_unknown';
Modes.StopReason.TransitionTimeout = 'transition_timeout';

Modes.DevelopmentFailure.None = 'none';
Modes.DevelopmentFailure.RestingProcessing = 'resting_processing';
Modes.DevelopmentFailure.Transition = 'transition';
Modes.DevelopmentFailure.TrialProcessing = 'trial_processing';
Modes.DevelopmentFailure.FeedbackUpdate = 'feedback_update';
Modes.DevelopmentFailure.LoggerAppend = 'logger_append';
Modes.DevelopmentFailure.LoggerClose = 'logger_close';

Modes.TestBufferCommand.Advance = 'test_advance';
Modes.TimingSource.TestHookLogical = 'test_hook_logical';
Modes.TimingSource.Monotonic = 'monotonic';
Modes.TimingSource.None = 'none';

Modes.ReadinessStatus.Pass = 'pass';
Modes.ReadinessStatus.Fail = 'fail';

Modes.TimelineEvent.SessionStart = 'session_start';
Modes.TimelineEvent.SourceReady = 'source_ready';
Modes.TimelineEvent.SpatialReady = 'spatial_ready';
Modes.TimelineEvent.LoggerReady = 'logger_ready';
Modes.TimelineEvent.RestingManualStart = 'resting_manual_start';
Modes.TimelineEvent.RestingStart = 'resting_start';
Modes.TimelineEvent.RestingFirstChunk = 'resting_first_chunk';
Modes.TimelineEvent.RestingEnd = 'resting_end';
Modes.TimelineEvent.BaselineFinalized = 'baseline_finalized';
Modes.TimelineEvent.BaselineSaved = 'baseline_saved';
Modes.TimelineEvent.BaselineReloaded = 'baseline_reloaded';
Modes.TimelineEvent.TransitionWaitStart = 'transition_wait_start';
Modes.TimelineEvent.TransitionWaitEnd = 'transition_wait_end';
Modes.TimelineEvent.TransitionTimeout = 'transition_timeout';
Modes.TimelineEvent.TransitionResync = 'transition_resync';
Modes.TimelineEvent.TransitionBacklogDiscarded = 'transition_backlog_discarded';
Modes.TimelineEvent.TrialStart = 'trial_start';
Modes.TimelineEvent.TrialFirstChunk = 'trial_first_chunk';
Modes.TimelineEvent.TrialFirstValidMeasure = 'trial_first_valid_measure';
Modes.TimelineEvent.FeedbackInitialized = 'feedback_initialized';
Modes.TimelineEvent.FeedbackFlip = 'feedback_flip';
Modes.TimelineEvent.TrialStop = 'trial_stop';
Modes.TimelineEvent.CleanupStart = 'cleanup_start';
Modes.TimelineEvent.CleanupEnd = 'cleanup_end';
Modes.TimelineEvent.PrimaryError = 'primary_error';
Modes.TimelineEvent.CleanupError = 'cleanup_error';
Modes.TimelineEvent.SessionComplete = 'session_complete';

Modes.BufferBacklog.DiscardAccumulated = 'discard_accumulated';
Modes.BufferBacklog.PreserveCursor = 'preserve_cursor';

Modes.BufferResetPolicy.Error = 'error';
Modes.BufferResetPolicy.ResyncToCurrentEnd = 'resync_to_current_end';

Modes.StreamRole.LocalReplay = 'local_replay';
Modes.StreamRole.LiveMEG = 'live_meg';
Modes.StreamRole.TestHook = 'test_hook';
Modes.StreamRole.Unknown = 'unknown';

Modes.SettingOrigin.Config = 'config';
Modes.SettingOrigin.DefaultConfig = 'default_config';
Modes.SettingOrigin.HistoricalBen = 'historical_ben';
Modes.SettingOrigin.CallerOverride = 'caller_override';

end
