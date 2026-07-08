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

RTConfig.Source.FieldTrip.BufferMPath = '';
RTConfig.Source.FieldTrip.FieldTripRoot = '';
RTConfig.Source.FieldTrip.RequiredBufferRoot = '';
RTConfig.Source.FieldTrip.AllowAlreadyOnPathBuffer = false;
RTConfig.Source.FieldTrip.AllowMatlabToolboxBuffer = false;
RTConfig.Source.FieldTrip.UseBrainstormPluginPaths = false;
RTConfig.Source.FieldTrip.UseCTFRes4FromHeader = true;

% Finalized conditionally in nf_finalize_config.
RTConfig.Source.FieldTrip.RequireCTFRes4 = [];
RTConfig.Source.FieldTrip.TestBufferFcn = [];

RTConfig.Source.FieldTrip.SettingOrigin.Host = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.Port = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.BufferMPath = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.FieldTripRoot = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.RequiredBufferRoot = 'unresolved';
RTConfig.Source.FieldTrip.SettingOrigin.UseBrainstormPluginPaths = 'config';

%% ===== TIMING =====
% Live/mock-live timing is fixed by the Step 3 acquisition contract.
RTConfig.Fs = 2400;

RTConfig.ChunkSeconds = 0.2;
RTConfig.ChunkSamples = 480;

RTConfig.PowerWindowSeconds = 2.0;
RTConfig.PowerWindowSamples = 4800;

RTConfig.BufferSeconds = 2.0;
RTConfig.BufferSamples = 4800;

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

RTConfig.Feedback.RequirePsychtoolboxForLive = true;
RTConfig.Feedback.AllowDebugPlotFallback = false;

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
RTConfig.Safety.UseMaxDurationFailsafe = true;
RTConfig.Safety.MaxConsecutiveTimeouts = 3;

% Do not define RTConfig.Safety.MaxDurationSeconds as an independent source
% of truth.

%% ===== COMM =====
RTConfig.Comm.EnableTriggers = false;

end
