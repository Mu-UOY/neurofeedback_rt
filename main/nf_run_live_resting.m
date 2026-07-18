function [Baseline, RestingResult, Source, Logger, Timeline] = ...
    nf_run_live_resting(RTConfig, Source, Spatial, Logger, Timeline)
% NF_RUN_LIVE_RESTING Collect a live resting baseline.
%
% USAGE:  [Baseline, RestingResult, Source, Logger] = nf_run_live_resting(RTConfig, Source, Spatial, Logger)

%% ===== PREPARE CONFIG =====
% Resting uses the RT core but does not map or display feedback.
Modes = nf_modes();
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_live_config();
end
if nargin < 2
    Source = [];
end
if nargin < 3
    Spatial = [];
end
if nargin < 4
    Logger = [];
end
if nargin < 5
    Timeline = [];
end

RTConfig.Session.Mode = Modes.Session.LiveResting;
RTConfig.Feedback.Mode = Modes.Feedback.None;
RTConfig.Baseline.MinValidWindows = RTConfig.LiveResting.MinValidMeasures;
RTConfig = local_finalize_preserving_root(RTConfig);

%% ===== INITIALIZE SOURCE AND SPATIAL =====
% Live acquisition and spatial preparation stay behind their public helpers.
if isempty(Source)
    Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
end
if isempty(Spatial)
    Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);
else
    Spatial = nf_revalidate_live_spatial_against_source(Spatial, Source, RTConfig);
end
RTConfig = local_attach_spatial(RTConfig, Spatial, Modes);
ownsLogger = isempty(Logger);
if ownsLogger
    Logger = nf_logger_init(RTConfig, Modes.Session.LiveResting, Source);
end

%% ===== INITIALIZE RESULT AND STATE =====
% Result schema is stable for self-test aggregation and audit save.
RestingResult = local_empty_resting_result(RTConfig);
RestingResult.Started = true;
RestingResult.TargetBand = RTConfig.TargetBand;
RestingResult.TargetBandLabel = local_field(RTConfig, 'TargetBandLabel', '');
RestingResult = local_attach_spatial_audit(RestingResult, Spatial);
Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.RestingStart, ...
    Modes.Phase.Resting, NaN, NaN, 'Resting phase started.', false);

Baseline = [];
LoopState = local_init_loop_state(Modes.Session.LiveResting, ...
    Modes.Session.LiveResting, RTConfig.LiveResting.MaxTimeouts);
Safety = [];
BaselineAcc = [];
try
    RT = nf_rt_prepare(RTConfig);
    BaselineAcc = nf_baseline_init(RTConfig, RT);
    Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveResting);

%% ===== MANUAL START AND RESYNC =====
% Backlog discard happens only after deliberate operator waits.
if local_owner_is(RTConfig, 'ManualStartOwner', Modes.PhaseRunnerOwner.Internal)
    RestingResult.ManualStartResult = nf_wait_for_manual_start(RTConfig, Modes.Session.LiveResting);
else
    RestingResult.ManualStartResult = local_external_owner_result('manual_start');
end
Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.RestingManualStart, ...
    Modes.Phase.Resting, NaN, NaN, RestingResult.ManualStartResult.Message, false);
if local_owner_is(RTConfig, 'ResyncOwner', Modes.PhaseRunnerOwner.Internal)
    [Source, RestingResult.SourceResyncInfo] = nf_source_resync_after_pause( ...
        Source, RTConfig, Modes.Session.LiveResting);
else
    RestingResult.SourceResyncInfo = local_external_owner_result('source_resync');
end

%% ===== RUN RESTING LOOP =====
% A configured live duration maps to a chunk count; live reads still block.
maxIterations = max(1, ceil(RTConfig.LiveResting.DurationSeconds ./ RTConfig.ChunkSeconds));
Measures = repmat(nf_measure_empty(), 0, 1);

for iIteration = 1:maxIterations
    LoopState.NIterations = iIteration;
    LoopState.ElapsedSeconds = toc(LoopState.StartTic);

    [manualStop, Safety] = nf_safety_check_stop(Safety, RTConfig);
    LoopState.ManualStopRequested = manualStop;
    LoopState.HardFailsafeExceeded = nf_safety_hard_failsafe_exceeded(Safety);
    Stop = nf_determine_stop_reason(Safety, struct(), RTConfig, LoopState);
    if Stop.ShouldStop
        RestingResult.StopReason = Stop.Reason;
        break;
    end

    try
        [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    catch ME
        LoopState.ErrorOccurred = true;
        LoopState.LastError = ME.message;
        Stop = nf_determine_stop_reason(Safety, struct(), RTConfig, LoopState);
        RestingResult.StopReason = Stop.Reason;
        RestingResult = local_record_error(RestingResult, ME);
        break;
    end

    [LoopState, isEmpty] = local_update_loop_for_chunk(LoopState, chunk, RTConfig);
    if isEmpty
        Stop = nf_determine_stop_reason(Safety, struct(), RTConfig, LoopState);
        if Stop.ShouldStop
            RestingResult.StopReason = Stop.Reason;
            break;
        end
        continue;
    end

    if ~isempty(Logger)
        Logger = nf_logger_append_chunk_meta(Logger, local_chunk_meta(chunk, Modes.Session.LiveResting, iIteration));
    end

    try
        nf_development_maybe_inject_failure(RTConfig, ...
            Modes.DevelopmentFailure.RestingProcessing, iIteration);
        [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
    catch ME
        LoopState.ErrorOccurred = true;
        LoopState.LastError = ME.message;
        Stop = nf_determine_stop_reason(Safety, struct(), RTConfig, LoopState);
        RestingResult.StopReason = Stop.Reason;
        RestingResult = local_record_error(RestingResult, ME);
        break;
    end

    if LoopState.NChunks == 1
        Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.RestingFirstChunk, ...
            Modes.Phase.Resting, chunk.SampleIndices(1), chunk.SampleIndices(end), ...
            'First resting chunk processed.', false);
    end

    Measures(end+1) = Measure; %#ok<AGROW>
    BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig);
    if Measure.IsValid && isfinite(Measure.Power)
        LoopState.NValidMeasures = LoopState.NValidMeasures + 1;
    else
        LoopState.NInvalidMeasures = LoopState.NInvalidMeasures + 1;
    end
    if ~isempty(Logger)
        nf_development_maybe_inject_failure(RTConfig, ...
            Modes.DevelopmentFailure.LoggerAppend, Logger.NMeasures + 1);
        Logger = nf_logger_append_measure(Logger, Measure);
        Logger = local_maybe_save_partial(Logger, Modes.Session.LiveResting, RTConfig, 'cadence');
    end
end

%% ===== FINALIZE BASELINE =====
% Baseline save errors become RestingResult failures.
if isempty(RestingResult.Error)
    try
        BaselineAcc = nf_baseline_reject_outliers(BaselineAcc, RTConfig);
        Baseline = nf_baseline_finalize(BaselineAcc, RTConfig);
        Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.BaselineFinalized, ...
            Modes.Phase.Resting, NaN, NaN, 'Baseline finalized.', false);
        Baseline.Quality = nf_baseline_check_quality(Baseline, RTConfig);
        RestingResult.BaselineQuality = Baseline.Quality;
        if Baseline.Quality.Pass
            RestingResult.BaselinePath = nf_save_baseline(Baseline, RTConfig);
            Baseline.OutputFile = RestingResult.BaselinePath;
            Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.BaselineSaved, ...
                Modes.Phase.Resting, NaN, NaN, RestingResult.BaselinePath, false);
        end
    catch ME
        RestingResult = local_record_error(RestingResult, ME);
        RestingResult.StopReason = Modes.StopReason.Error;
    end
end
catch ME
    LoopState.ErrorOccurred = true;
    LoopState.LastError = ME.message;
    RestingResult.StopReason = Modes.StopReason.Error;
    RestingResult = local_record_error(RestingResult, ME);
end

%% ===== FINALIZE RESULT =====
% Pass/fail formula is explicit and excludes timeout/failsafe/error stops.
if LoopState.ErrorOccurred || ~isempty(RestingResult.Error)
    RestingResult.Partial = true;
    Logger = local_attempt_partial_save(Logger, Modes.Session.LiveResting, 'error');
end
RestingResult.PartialLogPaths = local_partial_paths(Logger);
RestingResult.NChunks = LoopState.NChunks;
RestingResult.NEmptyChunks = LoopState.NEmptyChunks;
RestingResult.NTimeouts = LoopState.NTimeouts;
RestingResult.TimeoutLimitExceeded = LoopState.TimeoutLimitExceeded;
RestingResult.NValidMeasures = LoopState.NValidMeasures;
RestingResult.NInvalidMeasures = LoopState.NInvalidMeasures;
RestingResult.LastChunkStatus = LoopState.LastChunkStatus;
RestingResult.DurationSeconds = LoopState.ElapsedSeconds;

badStop = any(strcmp(RestingResult.StopReason, ...
    {Modes.StopReason.Error, Modes.StopReason.Timeout, Modes.StopReason.HardFailsafe}));
qualityPass = isstruct(RestingResult.BaselineQuality) && ...
    isfield(RestingResult.BaselineQuality, 'Pass') && RestingResult.BaselineQuality.Pass;
RestingResult.Pass = isempty(RestingResult.Error) && ~badStop && ...
    RestingResult.NValidMeasures >= RTConfig.LiveResting.MinValidMeasures && qualityPass;
RestingResult.Completed = RestingResult.Pass || ~badStop;
if RestingResult.Completed && isempty(RestingResult.Error)
    RestingResult.Partial = false;
end

[safetyMessages, safetyClosed] = local_cleanup_safety(Safety, RTConfig);
RestingResult.SafetyClosed = safetyClosed;
cleanupMessages = safetyMessages;
if ownsLogger
    [Logger, loggerMessages, loggerClosed] = local_cleanup_logger(Logger);
    RestingResult.LoggerClosed = loggerClosed;
    cleanupMessages = [cleanupMessages, loggerMessages];
else
    RestingResult.LoggerClosed = false;
end
RestingResult.SafetySummary = local_safety_summary(Safety);
RestingResult.CleanupMessages = cleanupMessages;
for iMessage = 1:numel(cleanupMessages)
    Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.CleanupError, ...
        Modes.Phase.Resting, NaN, NaN, cleanupMessages{iMessage}, true);
end
Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.RestingEnd, ...
    Modes.Phase.Resting, NaN, local_field(Source, 'LastSampleRead', NaN), ...
    'Resting phase ended.', ~RestingResult.Pass);

end

function Result = local_empty_resting_result(RTConfig)
% Create stable resting result schema.
Result = struct();
Result.Started = false;
Result.Completed = false;
Result.Partial = false;
Result.Pass = false;
Result.StopReason = '';
Result.NChunks = 0;
Result.NEmptyChunks = 0;
Result.NTimeouts = 0;
Result.MaxTimeouts = RTConfig.LiveResting.MaxTimeouts;
Result.TimeoutLimitExceeded = false;
Result.NValidMeasures = 0;
Result.NInvalidMeasures = 0;
Result.DurationSeconds = 0;
Result.TargetBand = [NaN NaN];
Result.TargetBandLabel = '';
Result.ManualStartResult = struct();
Result.SourceResyncInfo = struct();
Result.SafetySummary = struct();
Result.PartialLogPaths = {};
Result.CleanupMessages = {};
Result.LoggerClosed = false;
Result.SafetyClosed = false;
Result.BaselinePath = '';
Result.BaselineQuality = struct();
Result.LastChunkStatus = '';
Result.Error = '';
Result.ErrorIdentifier = '';
Result.ErrorReport = '';
Result.SpatialHash = '';
Result.SpatialMatrixSource = '';
Result.SpatialIsTechnicalFallback = false;
Result.SpatialIsIPS = false;
Result.SpatialSize = [NaN NaN];
Result.SpatialInputChannelNames = {};
end

function Result = local_attach_spatial_audit(Result, Spatial)
% Record the validated spatial object actually attached to this phase.
Result.SpatialHash = local_field(Spatial, 'Hash', '');
Result.SpatialMatrixSource = local_field(Spatial, 'MatrixSource', '');
Result.SpatialIsTechnicalFallback = local_logical_field(Spatial, ...
    'IsTechnicalFallback', false);
Result.SpatialIsIPS = local_logical_field(Spatial, 'IsIPS', false);
Result.SpatialSize = size(local_field(Spatial, 'CombinedMatrix', []));
Result.SpatialInputChannelNames = local_field(Spatial, 'InputChannelNames', {});
end

function Timeline = local_timeline_append(Timeline, eventType, phase, ...
    sampleStart, sampleEnd, message, isError)
% Append only when an explicit Step 0 timeline was supplied.
if isempty(Timeline) || ~isstruct(Timeline) || ~isfield(Timeline, 'Path')
    return;
end
Timeline = nf_development_timeline_append(Timeline, eventType, phase, ...
    sampleStart, sampleEnd, message, isError);
end

function Result = local_record_error(Result, ME)
% Attach full error audit without hiding cleanup failures.
Result.Error = ME.message;
Result.ErrorIdentifier = ME.identifier;
Result.ErrorReport = local_error_report(ME);
Result.Partial = true;
Result.Completed = false;
end

function report = local_error_report(ME)
% Build an extended report when MATLAB supports getReport.
try
    report = getReport(ME, 'extended', 'hyperlinks', 'off');
catch
    report = ME.message;
end
end

function Logger = local_maybe_save_partial(Logger, phase, RTConfig, reason)
% Save incremental partial logs on the configured measure cadence.
if nargin < 4 || isempty(reason)
    reason = 'cadence';
end
if ~isstruct(Logger) || isempty(Logger)
    return;
end
cadence = local_partial_cadence(RTConfig);
if cadence < 1 || Logger.NMeasures < 1 || mod(Logger.NMeasures, cadence) ~= 0 || ...
        Logger.NMeasures <= Logger.LastPartialSavedMeasureIndex
    return;
end
Logger = local_attempt_partial_save(Logger, phase, reason);
end

function cadence = local_partial_cadence(RTConfig)
% Prefer phase-specific cadence, then the shared logging flush cadence.
cadence = Inf;
if isfield(RTConfig, 'LiveResting') && isfield(RTConfig.LiveResting, 'SavePartialEveryNMeasures')
    cadence = RTConfig.LiveResting.SavePartialEveryNMeasures;
elseif isfield(RTConfig, 'Logging') && isfield(RTConfig.Logging, 'SavePartialEveryNMeasures')
    cadence = RTConfig.Logging.SavePartialEveryNMeasures;
elseif isfield(RTConfig, 'Logging') && isfield(RTConfig.Logging, 'FlushEveryNMeasures')
    cadence = RTConfig.Logging.FlushEveryNMeasures;
end
if ~isnumeric(cadence) || ~isscalar(cadence) || ~isfinite(cadence) || cadence < 1
    cadence = Inf;
else
    cadence = round(cadence);
end
end

function Logger = local_attempt_partial_save(Logger, phase, reason)
% Save partial log, recording save failures in the logger instead of throwing.
if ~isstruct(Logger) || isempty(Logger)
    return;
end
try
    Logger = nf_save_partial_log(Logger, phase, reason);
catch ME
    if isfield(Logger, 'Messages') && iscell(Logger.Messages)
        Logger.Messages{end+1} = sprintf('Partial save failed: %s', ME.message);
    end
end
end

function paths = local_partial_paths(Logger)
% Return logger partial checkpoint paths.
paths = {};
if isstruct(Logger) && isfield(Logger, 'PartialLogPaths')
    paths = Logger.PartialLogPaths;
end
end

function Summary = local_safety_summary(Safety)
% Build a compact safety audit summary.
Summary = struct();
Summary.Phase = local_field(Safety, 'Phase', '');
Summary.StopRequested = local_logical_field(Safety, 'StopRequested', false);
Summary.StopReason = local_field(Safety, 'StopReason', '');
Summary.MaxDurationSeconds = local_field(Safety, 'MaxDurationSeconds', NaN);
Summary.UseMaxDurationFailsafe = local_logical_field(Safety, 'UseMaxDurationFailsafe', false);
Summary.EnableStopFile = local_logical_field(Safety, 'EnableStopFile', false);
Summary.StopFilePath = local_field(Safety, 'StopFilePath', '');
end

function [messages, closed] = local_cleanup_safety(Safety, RTConfig)
% Shutdown safety without masking the original error.
messages = {};
closed = true;
if isempty(Safety)
    return;
end
try
    hooks = RTConfig.DevelopmentSession.TestHooks;
    if nf_is_strict_step0_headless_contract(RTConfig) && ...
            ~isempty(hooks.SafetyShutdownFcn)
        hooks.SafetyShutdownFcn(Safety);
    else
        nf_safety_shutdown(Safety);
    end
catch ME
    closed = false;
    messages{end+1} = sprintf('Safety cleanup failed: %s', ME.message);
end
end

function [Logger, messages, closed] = local_cleanup_logger(Logger)
% Close owned logger without masking the original error.
messages = {};
closed = true;
if isempty(Logger)
    return;
end
try
    Logger = nf_logger_close(Logger);
    closed = local_logical_field(Logger, 'Closed', false);
catch ME
    closed = false;
    messages{end+1} = sprintf('Logger cleanup failed: %s', ME.message);
end
end

function LoopState = local_init_loop_state(typeValue, phase, maxTimeouts)
% Initialize loop counters shared by live phases.
LoopState = struct();
LoopState.Type = typeValue;
LoopState.Phase = phase;
LoopState.StartedAt = local_now_text();
LoopState.StartTic = tic;
LoopState.ElapsedSeconds = 0;
LoopState.NIterations = 0;
LoopState.NChunks = 0;
LoopState.NEmptyChunks = 0;
LoopState.NTimeouts = 0;
LoopState.NConsecutiveTimeouts = 0;
LoopState.MaxTimeouts = maxTimeouts;
LoopState.NValidMeasures = 0;
LoopState.NInvalidMeasures = 0;
LoopState.LastChunkWasEmpty = false;
LoopState.LastChunkStatus = '';
LoopState.LastChunkSampleStart = NaN;
LoopState.LastChunkSampleEnd = NaN;
LoopState.ManualStopRequested = false;
LoopState.TimeoutLimitExceeded = false;
LoopState.HardFailsafeExceeded = false;
LoopState.FixedDurationCompleted = false;
LoopState.ErrorOccurred = false;
LoopState.LastError = '';
LoopState.FeedbackLatencyBudgetExceeded = false;
LoopState.NFeedbackLatencyWarnings = 0;
LoopState.NConsecutiveFeedbackLatencyWarnings = 0;
end

function [LoopState, isEmpty] = local_update_loop_for_chunk(LoopState, chunk, RTConfig)
% Update timeout and chunk counters.
isEmpty = isempty(chunk);
LoopState.LastChunkWasEmpty = isEmpty;
if isEmpty
    LoopState.NEmptyChunks = LoopState.NEmptyChunks + 1;
    if RTConfig.Safety.CountEmptyChunkAsTimeout
        LoopState.NTimeouts = LoopState.NTimeouts + 1;
        LoopState.NConsecutiveTimeouts = LoopState.NConsecutiveTimeouts + 1;
    end
    LoopState.LastChunkStatus = 'empty';
else
    LoopState.NChunks = LoopState.NChunks + 1;
    if RTConfig.Safety.ResetTimeoutCountOnValidChunk
        LoopState.NConsecutiveTimeouts = 0;
    end
    LoopState.LastChunkStatus = 'valid';
    LoopState.LastChunkSampleStart = chunk.SampleIndices(1);
    LoopState.LastChunkSampleEnd = chunk.SampleIndices(end);
end
LoopState.TimeoutLimitExceeded = LoopState.NConsecutiveTimeouts >= LoopState.MaxTimeouts && ...
    LoopState.NConsecutiveTimeouts > 0;
end

function RTConfig = local_finalize_preserving_root(RTConfig)
% Finalize while preserving caller-specified temporary output roots.
requestedProjectRoot = '';
requestedBaselinesDir = '';
requestedTrialsDir = '';
if isfield(RTConfig, 'Paths') && isfield(RTConfig.Paths, 'ProjectRoot')
    requestedProjectRoot = RTConfig.Paths.ProjectRoot;
end
if isfield(RTConfig, 'Paths') && isfield(RTConfig.Paths, 'BaselinesDir')
    requestedBaselinesDir = RTConfig.Paths.BaselinesDir;
end
if isfield(RTConfig, 'Paths') && isfield(RTConfig.Paths, 'TrialsDir')
    requestedTrialsDir = RTConfig.Paths.TrialsDir;
end
RTConfig = nf_finalize_config(RTConfig);
if ~isempty(requestedProjectRoot)
    RTConfig.Paths.ProjectRoot = requestedProjectRoot;
end
if ~isempty(requestedBaselinesDir)
    RTConfig.Paths.BaselinesDir = requestedBaselinesDir;
end
if ~isempty(requestedTrialsDir)
    RTConfig.Paths.TrialsDir = requestedTrialsDir;
end
end

function RTConfig = local_attach_spatial(RTConfig, Spatial, Modes)
% Attach prepared CombinedMatrix to config for nf_rt_prepare.
RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.CombinedMatrix = Spatial.CombinedMatrix;
RTConfig.Spatial.NChannels = size(Spatial.CombinedMatrix, 2);
RTConfig.Spatial.Prepared = Spatial;
end

function Meta = local_chunk_meta(chunk, phase, iChunk)
% Build compact chunk metadata for logger append.
Meta = chunk;
Meta.Phase = phase;
Meta.ChunkIndex = iChunk;
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function value = local_logical_field(S, fieldName, defaultValue)
% Read optional logical-like field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    raw = S.(fieldName);
    if islogical(raw) && isscalar(raw)
        value = raw;
    elseif isnumeric(raw) && isscalar(raw) && isfinite(raw)
        value = raw ~= 0;
    end
end
end

function value = local_now_text()
% Return a stable timestamp string.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
else
    value = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
end

function tf = local_owner_is(RTConfig, fieldName, expected)
% Compare a phase-runner owner against a centralized mode value.
tf = isfield(RTConfig, 'PhaseRunner') && isfield(RTConfig.PhaseRunner, fieldName) && ...
    strcmp(RTConfig.PhaseRunner.(fieldName), expected);
end

function Result = local_external_owner_result(typeValue)
% Return a stable marker when orchestration owns the phase boundary.
Result = struct('Type', typeValue, 'HandledExternally', true, ...
    'Applied', false, 'Message', 'Handled by external orchestrator.');
end
