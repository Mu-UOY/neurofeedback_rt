function RTConfig = nf_live_config()
% NF_LIVE_CONFIG Build the default Step 3 live-session config scaffold.
%
% DESCRIPTION:
%     Starts from nf_default_config and adds the hardware-free control fields
%     needed by later live-readiness steps. This function does not start
%     FieldTrip, Brainstorm, feedback, logging, safety loops, or source reads.

Modes = nf_modes();
RTConfig = nf_default_config();

%% ===== INTERNAL =====
% Finalization derives dependent fields and performs strict live checks.
RTConfig.Internal.IsFinalized = false;

%% ===== SESSION =====
RTConfig.Session.Mode = Modes.Session.LiveSelfTest;
RTConfig.Session.DevelopmentOnly = false;
RTConfig.Session.ProductionEquivalent = false;

%% ===== PHASE RUNNER OWNERSHIP =====
RTConfig.PhaseRunner.ManualStartOwner = Modes.PhaseRunnerOwner.Internal;
RTConfig.PhaseRunner.ResyncOwner = Modes.PhaseRunnerOwner.Internal;

%% ===== SOURCE =====
RTConfig.Source.Mode = Modes.Source.LiveFieldTrip;
RTConfig.Source.LiveAdapter = Modes.LiveAdapter.BenFieldTrip;

% Benjamin wiring evidence was not found in this repository during Step 3A.
% Keep live connection values explicit and unresolved until the MEG-room
% operator fills them in or Benjamin's recovered code is made available.
RTConfig.Source.Benjamin.CodeRoot = '';
RTConfig.Source.Benjamin.WiringNotes = {};
RTConfig.Source.Benjamin.WiringEvidenceFiles = {};

RTConfig.Source.FieldTrip.Host = '';
RTConfig.Source.FieldTrip.Port = [];
RTConfig.Source.FieldTrip.TimeoutMs = 10000;
RTConfig.Source.FieldTrip.HeaderPollSeconds = 0.05;

RTConfig.Source.FieldTrip.BufferMPath = '';
RTConfig.Source.FieldTrip.FieldTripRoot = '';
RTConfig.Source.FieldTrip.RequiredBufferRoot = '';
RTConfig.Source.FieldTrip.AllowAlreadyOnPathBuffer = false;
RTConfig.Source.FieldTrip.AllowMatlabToolboxBuffer = false;
RTConfig.Source.FieldTrip.UseBrainstormPluginPaths = false;
RTConfig.Source.FieldTrip.UseCTFRes4FromHeader = true;
RTConfig.Source.FieldTrip.AfterManualStartBacklogPolicy = ...
    Modes.BufferBacklog.DiscardAccumulated;
RTConfig.Source.FieldTrip.BufferResetPolicy = Modes.BufferResetPolicy.Error;
RTConfig.Source.FieldTrip.StreamRole = Modes.StreamRole.Unknown;

% Finalized conditionally in nf_finalize_config.
RTConfig.Source.FieldTrip.RequireCTFRes4 = [];
RTConfig.Source.FieldTrip.TestBufferFcn = [];

RTConfig.Source.FieldTrip.SettingOrigin.Host = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.Port = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.BufferMPath = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.FieldTripRoot = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.RequiredBufferRoot = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.UseBrainstormPluginPaths = Modes.SettingOrigin.Config;

%% ===== MEG ROOM =====
RTConfig.MEGRoom.SiteLabel = 'BIC_MEG';
RTConfig.MEGRoom.Operator = '';
RTConfig.MEGRoom.SubjectCode = '';
RTConfig.MEGRoom.SessionLabel = '';
RTConfig.MEGRoom.Notes = '';
RTConfig.MEGRoom.HostPresetLabel = '';
RTConfig.MEGRoom.AllowHistoricalBenDefaults = false;
RTConfig.MEGRoom.BenHistorical.FTHost = '10.0.0.2';
RTConfig.MEGRoom.BenHistorical.FTPort = 1972;
RTConfig.MEGRoom.BenHistorical.BlockTimeMs = 1000;

%% ===== TIMING =====
% Live/mock-live timing is fixed by the Step 3 acquisition contract.
RTConfig.Fs = 2400;

RTConfig.ChunkSeconds = 0.2;
RTConfig.ChunkSamples = 480;

RTConfig.PowerWindowSeconds = 2.0;
RTConfig.PowerWindowSamples = 4800;

RTConfig.BufferSeconds = 2.0;
RTConfig.BufferSamples = 4800;

RTConfig.TargetBandLabel = 'theta';

%% ===== PROCESSING =====
RTConfig.Filter.Type = Modes.Filter.IIRSOS;

% Uniform Step 3 live/mock-live spatial contract.
RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;

% Default intended live path. Acquisition-only sessions may keep this empty.
% Spatial/RT sessions must provide a valid path or switch to TechnicalFallback.
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = '';

% Technical fallback config only. The actual fallback matrix builder is not
% implemented in Step 3A-0a.
RTConfig.Spatial.Fallback.Type = 'single_channel';  % 'single_channel' or 'channel_average'
RTConfig.Spatial.Fallback.ChannelIndex = 1;
RTConfig.Spatial.Fallback.ChannelName = '';
RTConfig.Spatial.Fallback.ChannelNames = {};
RTConfig.Spatial.Fallback.NormalizeWeights = true;
RTConfig.Spatial.Fallback.AllowIfNoIPSMatrix = true;

%% ===== CTF CORRECTION CONFIG ONLY =====
% Candidate live defaults for later Step 3A/MEG-room work pending Marc review.
RTConfig.Source.CTF.ApplyChannelGains = true;
RTConfig.Source.CTF.ApplyMegRefCorrection = true;
RTConfig.Source.CTF.RemoveBlockMean = true;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.CTF.RequireMarcConfirmation = true;
RTConfig.Source.CTF.MarcConfirmed = false;

RTConfig.Source.CTF.CorrectionOrder = { ...
    'ChannelGains', ...
    'MegRefCorrection', ...
    'BlockMeanRemoval', ...
    'ProjectorIfEnabled'};

RTConfig.Debug.SaveFirstChunksForCorrectionValidation = 5;

%% ===== FEEDBACK CONFIG ONLY =====
% Feedback implementation is not part of Step 3A-0a.
RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.Psychtoolbox;
RTConfig.Feedback.MapSource = 'ZSmoothed';
RTConfig.Feedback.UpdateEveryNValidMeasures = 1;

RTConfig.Feedback.Circle.Color = [0 255 0];
RTConfig.Feedback.Circle.BackgroundColor = [128 128 128];
RTConfig.Feedback.Circle.OuterCircleColor = [0 255 0];
RTConfig.Feedback.Circle.ZMin = -3;
RTConfig.Feedback.Circle.ZMax = 3;
RTConfig.Feedback.Circle.MinRadiusPx = 20;
RTConfig.Feedback.Circle.MaxRadiusPx = 220;
RTConfig.Feedback.Circle.UseAreaProportionalMapping = true;
RTConfig.Feedback.Circle.VisualAlpha = 1.0;
RTConfig.Feedback.Circle.ShowOuterCircle = true;
RTConfig.Feedback.Circle.ShowFixation = true;
RTConfig.Feedback.Circle.InstructionText = ...
    'Try to make the green disk as large as possible.';
RTConfig.Feedback.Circle.HideMeaningFromParticipant = true;
RTConfig.Feedback.Circle.DebugAxesMarginScale = 1.1;
RTConfig.Feedback.Circle.FixationMinHalfWidthPx = 3;
RTConfig.Feedback.Circle.FixationHalfWidthFraction = 0.025;
RTConfig.Feedback.Circle.OuterCircleLineWidthPx = 2;
RTConfig.Feedback.Circle.FixationLineWidthPx = 1;

RTConfig.Feedback.RequirePsychtoolboxForLive = true;
RTConfig.Feedback.AllowDebugPlotFallback = false;
RTConfig.Feedback.LatencyBudgetMs = 25;
RTConfig.Feedback.LatencySummary.Percentile = 95;
RTConfig.Feedback.WarnOnLatencyBudgetExceeded = true;
RTConfig.Feedback.FailOnLatencyBudgetExceeded = false;
RTConfig.Feedback.MaxConsecutiveLatencyWarnings = 5;

%% ===== DEBUG =====
RTConfig.Debug.CheckMeasureSchema = true;
RTConfig.Debug.CheckRTSchema = true;
RTConfig.Debug.Verbose = true;
RTConfig.Debug.AllowNonLiveTimingInMock = false;

%% ===== MOCK-LIVE CONFIG ONLY =====
% Mock-live source implementation is not part of Step 3A-0a.
RTConfig.MockLive.RandomSeed = 1;
RTConfig.MockLive.UseDeterministicData = true;
RTConfig.MockLive.FixturePath = '';

%% ===== PROTOCOL =====
RTConfig.Protocol.RequireManualStart = true;
RTConfig.Protocol.ManualStartPrompt = 'Press any key to start the live phase.';
RTConfig.Protocol.AllowAutoStartForTestHook = false;
RTConfig.Protocol.ManualStartMaxWaitSeconds = Inf;
RTConfig.Protocol.ManualStartPollSeconds = 0.01;
RTConfig.Protocol.DurationSeconds.Resting = 180;

RTConfig.Protocol.Trial.StopRule = Modes.TrialStop.ManualOrSuccess;
RTConfig.Protocol.Trial.Success.Enabled = false;
RTConfig.Protocol.Trial.Success.SourceField = 'ZSmoothed';
RTConfig.Protocol.Trial.Success.Threshold = 1.0;
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = 20;

% Single source of truth for the trial hard failsafe.
RTConfig.Protocol.Trial.MaxFailsafeSeconds = 30 * 60;

%% ===== LOGGING CONFIG ONLY =====
% Logger implementation is not part of Step 3A-0a.
RTConfig.Logging.SaveProjectedFilteredTrace = true;
RTConfig.Logging.SaveRawChunksLocal = false;
RTConfig.Logging.FlushEveryNMeasures = 25;
RTConfig.Logging.SaveFormat = 'matfile';
RTConfig.Logging.StoreTracesAsSingle = true;

%% ===== LIVE DRY RUN CONFIG ONLY =====
RTConfig.LiveDryRun.TimeoutSecs = 5;
RTConfig.LiveDryRun.ExpectedFs = 2400;
RTConfig.LiveDryRun.RequireChannelLabels = true;
RTConfig.LiveDryRun.RequireSamplingRateMatch = true;
RTConfig.LiveDryRun.RunDuringConfigCheck = false;
RTConfig.LiveDryRun.DurationSeconds = 30;

%% ===== LIVE CHUNK SMOKE TEST =====
RTConfig.LiveChunkSmokeTest.NChunks = 50;
RTConfig.LiveChunkSmokeTest.SaveChunkMetadata = true;
RTConfig.LiveChunkSmokeTest.SaveFirstChunkPreview = true;
RTConfig.LiveChunkSmokeTest.MaxTimeouts = 0;
RTConfig.LiveChunkSmokeTest.FirstChunkPreviewMaxSamples = 200;
RTConfig.LiveChunkSmokeTest.FirstChunkPreviewMaxChannels = 10;

%% ===== LIVE RT DRY RUN =====
RTConfig.LiveRTDryRun.NChunks = 35;
RTConfig.LiveRTDryRun.DurationSeconds = 30;
RTConfig.LiveRTDryRun.MaxTimeouts = 0;
RTConfig.LiveRTDryRun.RequireAtLeastOneValidMeasure = true;
RTConfig.LiveRTDryRun.RequireFeedbackNaN = true;
RTConfig.LiveRTDryRun.RequireNoBaseline = true;
RTConfig.LiveRTDryRun.RequireTimingPass = false;
RTConfig.LiveRTDryRun.TimingWarningSeconds = RTConfig.ChunkSeconds;
RTConfig.LiveRTDryRun.SaveMeasures = true;
RTConfig.LiveRTDryRun.SaveRTSummary = true;
RTConfig.LiveRTDryRun.SaveChunkMetadata = true;

%% ===== SAFETY CONFIG ONLY =====
% Safety runtime helpers are not part of Step 3A-0a.
RTConfig.Safety.EnableKeyboardStop = true;
RTConfig.Safety.StopKey = 'ESCAPE';
RTConfig.Safety.SecondaryStopKey = 'q';
RTConfig.Safety.EnableStopFile = true;
RTConfig.Safety.StopFilePath = fullfile(tempdir, 'neurofeedback_rt_stop.txt');
RTConfig.Safety.UseMaxDurationFailsafe = true;
RTConfig.Safety.MaxConsecutiveTimeouts = 3;
RTConfig.Safety.ResetTimeoutCountOnValidChunk = true;
RTConfig.Safety.CountEmptyChunkAsTimeout = true;
RTConfig.Safety.CountRecoverableSourceTimeoutAsTimeout = true;

% Do not define RTConfig.Safety.MaxDurationSeconds as an independent source
% of truth.

%% ===== LIVE SELF TEST =====
RTConfig.LiveSelfTest.RunPreflightDiagnostics = false;
RTConfig.LiveSelfTest.RunChannelCheck = false;
RTConfig.LiveSelfTest.RunChunkSmokeTest = false;
RTConfig.LiveSelfTest.RunRTDryRun = false;
RTConfig.LiveSelfTest.RequireRestingPass = true;
RTConfig.LiveSelfTest.RequireTrialStarted = true;
RTConfig.LiveSelfTest.RequireAtLeastOneFeedbackUpdate = true;
RTConfig.LiveSelfTest.SaveAudit = true;
RTConfig.LiveSelfTest.CloseFeedbackOnError = true;

%% ===== LIVE RESTING =====
RTConfig.LiveResting.DurationSeconds = RTConfig.Protocol.DurationSeconds.Resting;
RTConfig.LiveResting.MinValidMeasures = RTConfig.Baseline.MinValidWindows;
RTConfig.LiveResting.MaxTimeouts = RTConfig.Safety.MaxConsecutiveTimeouts;
RTConfig.LiveResting.SaveMeasures = true;
RTConfig.LiveResting.SaveChunkMetadata = true;
RTConfig.LiveResting.SavePartialEveryNMeasures = RTConfig.Logging.FlushEveryNMeasures;

%% ===== LIVE TRIAL =====
RTConfig.LiveTrial.StopRule = RTConfig.Protocol.Trial.StopRule;
% Derived mirror for reports/tests only; runtime uses Protocol.Trial.MaxFailsafeSeconds.
RTConfig.LiveTrial.MaxFailsafeSeconds = RTConfig.Protocol.Trial.MaxFailsafeSeconds;
RTConfig.LiveTrial.MaxTimeouts = RTConfig.Safety.MaxConsecutiveTimeouts;
RTConfig.LiveTrial.RequireAtLeastOneValidMeasure = true;
RTConfig.LiveTrial.RequireAtLeastOneFeedbackUpdate = true;
RTConfig.LiveTrial.SaveMeasures = true;
RTConfig.LiveTrial.SaveChunkMetadata = true;
RTConfig.LiveTrial.SavePartialEveryNMeasures = RTConfig.Logging.FlushEveryNMeasures;

%% ===== STEP 0 DEVELOPMENT SESSION =====
RTConfig.DevelopmentSession.Enabled = false;
RTConfig.DevelopmentSession.DisplayMode = '';

RTConfig.DevelopmentSession.Hardware.Site = 'McGill_BIC';
RTConfig.DevelopmentSession.Hardware.System = 'CTF_MEG_2005_Series';

% STEP 0 PROVISIONAL ROOM-REPRESENTATIVE WORKLOAD:
% The McGill BIC CTF system has 275 primary MEG channels and 29 MEG reference
% channels. Step 0 therefore models a 304-channel MEG+MEGREF input block.
% EEG/analog/digital channels are excluded by explicit provisional policy.
% The 2048 output rows are a conservative pre-Step-5 IPS source-row workload.
% Step 3 must replace the input layout after real FieldTrip characterization.
% Step 5 must replace the output rows/class/density after constructing the
% real IPS matrix. Rerun all Step 0 tests after either replacement.
RTConfig.DevelopmentSession.Input.Policy = Modes.DevelopmentInput.MEGPlusMEGReference;
RTConfig.DevelopmentSession.Input.PrimaryMEGChannelCount = 275;
RTConfig.DevelopmentSession.Input.ReferenceMEGChannelCount = 29;
RTConfig.DevelopmentSession.Input.IncludeEEG = false;
RTConfig.DevelopmentSession.Input.IncludeAnalog = false;
RTConfig.DevelopmentSession.Input.IncludeDigital = false;
RTConfig.DevelopmentSession.Input.TotalChannelCount = [];
RTConfig.DevelopmentSession.Input.ReferenceLabelPrefix = 'MREF';
RTConfig.DevelopmentSession.Input.ReferenceLabelsAreProvisional = true;
RTConfig.DevelopmentSession.Input.PrimaryLabelSource = 'FieldTrip_CTF275_layout';
RTConfig.DevelopmentSession.Input.ReferenceLabelSource = ...
    'provisional_pending_FieldTrip_characterization';

RTConfig.DevelopmentSession.Matrix.OutputRowUpperBound = 2048;
RTConfig.DevelopmentSession.Matrix.Density = 1.0;
RTConfig.DevelopmentSession.Matrix.NumericClass = 'double';
RTConfig.DevelopmentSession.Matrix.RandomSeed = 1;
RTConfig.DevelopmentSession.Matrix.Orientation = Modes.MatrixOrientation.OutputByInput;
RTConfig.DevelopmentSession.Matrix.ScaleByInputSqrt = true;

RTConfig.DevelopmentSession.Transition.MaxPauseSeconds = 120;
RTConfig.DevelopmentSession.Transition.RequireExactSkippedRange = true;
RTConfig.DevelopmentSession.Transition.TestAdvanceChunks = 2;
RTConfig.DevelopmentSession.Transition.TestAdvanceSamples = [];
RTConfig.DevelopmentSession.Transition.TimeoutBoundaryDeltaSeconds = 1e-6;

RTConfig.DevelopmentSession.Source.InitialAvailableChunks = 10;
RTConfig.DevelopmentSession.Source.InitialAvailableSamples = [];
RTConfig.DevelopmentSession.Source.CapacitySeconds = 30 * 60;
RTConfig.DevelopmentSession.Source.CapacitySamples = [];
RTConfig.DevelopmentSession.Source.ThetaFrequencyHz = 6;
RTConfig.DevelopmentSession.Source.ThetaAmplitude = 1.0;
RTConfig.DevelopmentSession.Source.AmplitudeModulationHz = 0.1;
RTConfig.DevelopmentSession.Source.NoiseStd = 0.05;
RTConfig.DevelopmentSession.Source.RandomSeed = 1;
RTConfig.DevelopmentSession.Source.ReferenceAmplitudeScale = 0.25;
RTConfig.DevelopmentSession.Source.WaitPollSeconds = 0.005;
RTConfig.DevelopmentSession.Source.ReadinessTimeoutSeconds = 1.0;
RTConfig.DevelopmentSession.Source.ReadinessAdvanceChunks = 1;
RTConfig.DevelopmentSession.Source.ReadinessAdvanceSamples = [];

RTConfig.DevelopmentSession.Feedback.ScreenSelectionPolicy = ...
    Modes.ScreenSelection.HighestIndex;
RTConfig.DevelopmentSession.Feedback.ScreenNumber = [];
RTConfig.DevelopmentSession.Feedback.WindowRect = [];
RTConfig.DevelopmentSession.Feedback.FlipWhen = 0;
RTConfig.DevelopmentSession.Feedback.SkipSyncTests = false;

RTConfig.DevelopmentSession.RequireTimeline = true;
RTConfig.DevelopmentSession.RequirePsychtoolboxAudit = true;
RTConfig.DevelopmentSession.Output.SuccessMatFilename = 'development_session_summary.mat';
RTConfig.DevelopmentSession.Output.SuccessCsvFilename = 'development_session_summary.csv';
RTConfig.DevelopmentSession.Output.PartialMatFilename = 'partial_development_session_summary.mat';
RTConfig.DevelopmentSession.Output.PartialCsvFilename = 'partial_development_session_summary.csv';
RTConfig.DevelopmentSession.Output.TimelineFilename = 'session_timeline.html';
RTConfig.DevelopmentSession.Output.AtomicTempSuffix = '.tmp';

RTConfig.DevelopmentSession.TestHooks.Enabled = false;
RTConfig.DevelopmentSession.TestHooks.FailurePoint = Modes.DevelopmentFailure.None;
RTConfig.DevelopmentSession.TestHooks.FailureOccurrence = 1;
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Resting = 0;
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = 0;
RTConfig.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Trial = 0;
RTConfig.DevelopmentSession.TestHooks.ScreenFcn = [];
RTConfig.DevelopmentSession.TestHooks.TimeFcn = [];
RTConfig.DevelopmentSession.TestHooks.SafetyShutdownFcn = [];
RTConfig.DevelopmentSession.TestHooks.PauseFcn = [];

%% ===== COMM =====
RTConfig.Comm.EnableTriggers = false;

end
