function RT = nf_rt_init_schema()
% NF_RT_INIT_SCHEMA Create one canonical empty RT state struct.
%
% USAGE:  RT = nf_rt_init_schema()
%
% DESCRIPTION:
%     Returns the mutable real-time state schema used across preparation,
%     chunk processing, diagnostics, buffering, filtering, and z-score
%     smoothing.

%% ===== INITIALIZE RT STRUCT =====
% Top-level fields describe whether the state is prepared and baseline-aware.
RT = struct();

RT.HasBaseline = false;
RT.SourceMode = '';
RT.PreparedAt = '';

%% ===== PLACEHOLDER PROCESSING STATE =====
% These substructs are populated during nf_rt_prepare.
RT.Filter = struct();
RT.Buffer = struct();

%% ===== SPATIAL STATE =====
% Spatial metadata describes channel-to-signal projection.
RT.Spatial = struct();
RT.Spatial.Mode = '';
RT.Spatial.CombinedMatrix = [];
RT.Spatial.NChannels = NaN;
RT.Spatial.NSignals = NaN;

%% ===== HASH STATE =====
% Hashes are deterministic fingerprints for debugging and provenance.
RT.Hash = struct();
RT.Hash.FilterHash = '';
RT.Hash.SpatialHash = '';
RT.Hash.ArtifactProjectorHash = '';
RT.Hash.ReferenceCorrectionHash = '';
RT.Hash.InverseKernelHash = '';
RT.Hash.ScoutHash = '';

RT.ConfigHash = '';
RT.ConfigHashInputs = struct();

%% ===== Z-SCORE SMOOTHING STATE =====
% Smoothing state updates only after valid baseline-normalized measures.
RT.ZSmoothState = struct();
RT.ZSmoothState.LastZSmoothed = NaN;
RT.ZSmoothState.Initialized = false;
RT.ZSmoothState.Alpha = NaN;
RT.ZSmoothState.LastUpdateSample = NaN;

%% ===== SAMPLE COUNTERS =====
% Counters summarize chunk progress and sample continuity.
RT.SampleCounter = struct();
RT.SampleCounter.ChunkCount = 0;
RT.SampleCounter.TotalReceived = 0;
RT.SampleCounter.TotalValid = 0;
RT.SampleCounter.TotalDroppedSamples = 0;
RT.SampleCounter.LastSampleIndex = NaN;
RT.SampleCounter.LastChunkNSamples = NaN;

%% ===== TIMING STATE =====
% ChunkProcessingTimes records wall-clock processing duration per chunk.
RT.Timing = struct();
RT.Timing.ChunkProcessingTimes = [];
RT.Timing.LastLocalTime = [];

%% ===== DIAGNOSTIC COUNTERS =====
% Diagnostics record dropped, duplicated, late, or invalid chunks.
RT.Diagnostics = struct();
RT.Diagnostics.DroppedChunkCount = 0;
RT.Diagnostics.DuplicatedChunkCount = 0;
RT.Diagnostics.LateChunkCount = 0;
RT.Diagnostics.InvalidChunkCount = 0;
RT.Diagnostics.LastInvalidReason = '';

%% ===== BASELINE STATE =====
% Baseline fields are used for z-score normalization when available.
RT.Baseline = struct();
RT.Baseline.Mean = NaN;
RT.Baseline.Std = NaN;
RT.Baseline.PowerMean = NaN;
RT.Baseline.PowerStd = NaN;
RT.Baseline.ConfigHash = '';
RT.Baseline.IsFinalized = false;

end
