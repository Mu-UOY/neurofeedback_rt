function [TrialResult, Source, Logger, Timeline] = ...
    nf_run_live_trial(RTConfig, Source, Spatial, Baseline, Logger, Timeline)
% NF_RUN_LIVE_TRIAL Run live feedback using a finalized baseline.
%
% USAGE:  [TrialResult, Source, Logger] = nf_run_live_trial(RTConfig, Source, Spatial, Baseline, Logger)

%% ===== PREPARE CONFIG =====
% Trial keeps feedback outside the RT core and uses baseline z-scoring.
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
    Baseline = [];
end
if nargin < 5
    Logger = [];
end
if nargin < 6
    Timeline = [];
end

RTConfig.Session.Mode = Modes.Session.LiveTrial;
RTConfig = local_finalize_preserving_root(RTConfig);

%% ===== VALIDATE BASELINE =====
% Z-scoring is owned by nf_rt_process_chunk through nf_rt_prepare.
Quality = nf_baseline_check_quality(Baseline, RTConfig);
if ~Quality.Pass
    error('Live trial baseline quality failed: %s', Quality.Message);
end

%% ===== INITIALIZE SOURCE, SPATIAL, RT, AND FEEDBACK =====
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
    Logger = nf_logger_init(RTConfig, Modes.Session.LiveTrial, Source);
end

TrialResult = local_empty_trial_result(RTConfig);
TrialResult.Started = true;
TrialResult.TargetBand = RTConfig.TargetBand;
TrialResult.TargetBandLabel = local_field(RTConfig, 'TargetBandLabel', '');
TrialResult.FeedbackMode = RTConfig.Feedback.Mode;
TrialResult.FeedbackBackend = RTConfig.Feedback.Backend;
TrialResult.FeedbackMapSource = RTConfig.Feedback.MapSource;
TrialResult.FeedbackLatencyBudgetMs = RTConfig.Feedback.LatencyBudgetMs;
TrialResult.BaselineConfigHash = local_field(Baseline, 'ConfigHash', '');
TrialResult = local_attach_spatial_audit(TrialResult, Spatial);
Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.TrialStart, ...
    Modes.Phase.Trial, NaN, NaN, 'Trial phase started with fresh RT state.', false);

LoopState = local_init_loop_state(Modes.Session.LiveTrial, ...
    Modes.Session.LiveTrial, RTConfig.LiveTrial.MaxTimeouts);
TrialState = local_init_trial_state();
feedbackLatencies = [];
Feedback = [];
Safety = [];

try
    RT = nf_rt_prepare(RTConfig, Baseline);
    Feedback = nf_feedback_init(RTConfig);
    Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.FeedbackInitialized, ...
        Modes.Phase.Trial, NaN, NaN, 'Development Psychtoolbox feedback initialized.', false);
    Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveTrial);

%% ===== MANUAL START AND RESYNC =====
if local_owner_is(RTConfig, 'ManualStartOwner', Modes.PhaseRunnerOwner.Internal)
    TrialResult.ManualStartResult = nf_wait_for_manual_start(RTConfig, Modes.Session.LiveTrial);
else
    TrialResult.ManualStartResult = local_external_owner_result('manual_start');
end
if local_owner_is(RTConfig, 'ResyncOwner', Modes.PhaseRunnerOwner.Internal)
    [Source, TrialResult.SourceResyncInfo] = nf_source_resync_after_pause( ...
        Source, RTConfig, Modes.Session.LiveTrial);
else
    TrialResult.SourceResyncInfo = local_external_owner_result('source_resync');
end

%% ===== RUN TRIAL LOOP =====
% Manual/success/timeout/failsafe priority is centralized in the stop helper.
useMaxDurationFailsafe = local_use_max_duration_failsafe(RTConfig);
maxIterations = local_trial_max_iterations(RTConfig, useMaxDurationFailsafe);
iIteration = 0;
while true
    if isfinite(maxIterations) && iIteration >= maxIterations
        break;
    end
    iIteration = iIteration + 1;
    LoopState.NIterations = iIteration;
    LoopState.ElapsedSeconds = toc(LoopState.StartTic);

    [manualStop, Safety] = nf_safety_check_stop(Safety, RTConfig);
    LoopState.ManualStopRequested = manualStop;
    LoopState.HardFailsafeExceeded = nf_safety_hard_failsafe_exceeded(Safety);
    Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState);
    if Stop.ShouldStop
        TrialResult.StopReason = Stop.Reason;
        break;
    end

    try
        [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    catch ME
        LoopState.ErrorOccurred = true;
        LoopState.LastError = ME.message;
        Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState);
        TrialResult.StopReason = Stop.Reason;
        TrialResult = local_record_error(TrialResult, ME);
        break;
    end

    [LoopState, isEmpty] = local_update_loop_for_chunk(LoopState, chunk, RTConfig);
    if isEmpty
        Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState);
        if Stop.ShouldStop
            TrialResult.StopReason = Stop.Reason;
            break;
        end
        continue;
    end
    if ~isfinite(TrialResult.FirstTrialSample)
        TrialResult.FirstTrialSample = chunk.SampleIndices(1);
    end
    TrialResult.LastTrialSample = chunk.SampleIndices(end);
    if ~isempty(Logger)
        Logger = nf_logger_append_chunk_meta(Logger, local_chunk_meta(chunk, Modes.Session.LiveTrial, iIteration));
    end

    try
        nf_development_maybe_inject_failure(RTConfig, ...
            Modes.DevelopmentFailure.TrialProcessing, iIteration);
        [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
    catch ME
        LoopState.ErrorOccurred = true;
        LoopState.LastError = ME.message;
        Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState);
        TrialResult.StopReason = Stop.Reason;
        TrialResult = local_record_error(TrialResult, ME);
        break;
    end
    if LoopState.NChunks == 1
        Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.TrialFirstChunk, ...
            Modes.Phase.Trial, chunk.SampleIndices(1), chunk.SampleIndices(end), ...
            'First fresh trial chunk processed.', false);
    end

    if Measure.IsValid
        TrialState.NValidMeasures = TrialState.NValidMeasures + 1;
        LoopState.NValidMeasures = LoopState.NValidMeasures + 1;
        Measure.ValidMeasureIndex = TrialState.NValidMeasures;
        if ~isfinite(TrialResult.FirstValidMeasureWindowEndSample)
            TrialResult.FirstValidMeasureWindowEndSample = Measure.WindowEndSample;
            TrialResult.FreshSamplesBeforeFirstValidMeasure = ...
                Measure.WindowEndSample - TrialResult.FirstTrialSample + 1;
            Timeline = local_timeline_append(Timeline, ...
                Modes.TimelineEvent.TrialFirstValidMeasure, Modes.Phase.Trial, ...
                Measure.WindowStartSample, Measure.WindowEndSample, ...
                'First valid fresh trial measure.', false);
        end
    else
        LoopState.NInvalidMeasures = LoopState.NInvalidMeasures + 1;
    end
    TrialResult.NFiniteZRaw = TrialResult.NFiniteZRaw + double(isfinite(Measure.ZRaw));
    TrialResult.NFiniteZClipped = TrialResult.NFiniteZClipped + double(isfinite(Measure.ZClipped));
    TrialResult.NFiniteZSmoothed = TrialResult.NFiniteZSmoothed + double(isfinite(Measure.ZSmoothed));

    if nf_feedback_should_update(Measure, RT, RTConfig)
        tFeedback = tic;
        Measure = nf_feedback_map_to_display(Measure, RTConfig);
        nf_development_maybe_inject_failure(RTConfig, ...
            Modes.DevelopmentFailure.FeedbackUpdate, TrialState.NFeedbackUpdates + 1);
        nFlipAuditBefore = numel(local_field(Feedback, 'FlipAudit', struct([])));
        [Feedback, Measure] = nf_feedback_update(Feedback, Measure, RTConfig);
        if numel(local_field(Feedback, 'FlipAudit', struct([]))) > nFlipAuditBefore
            flip = Feedback.FlipAudit(end);
            Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.FeedbackFlip, ...
                Modes.Phase.Trial, flip.WindowStartSample, flip.WindowEndSample, ...
                sprintf(['Feedback flip completed at %.9g; missed deadline ' ...
                'estimate %.9g s; deadline missed %d.'], flip.FlipTimestamp, ...
                flip.Missed, flip.DeadlineMissed), false);
        end
        % Convert MATLAB's elapsed seconds to the configured millisecond budget.
        latencyMs = 1000 .* toc(tFeedback);
        feedbackLatencies(end+1) = latencyMs; %#ok<AGROW>
        TrialState.NFeedbackUpdates = TrialState.NFeedbackUpdates + 1;
        if ~isfinite(TrialResult.FirstFeedbackUpdateWindowEndSample)
            TrialResult.FirstFeedbackUpdateWindowEndSample = Measure.WindowEndSample;
        end
        LoopState = local_update_latency_state(LoopState, latencyMs, RTConfig);
    end

    [~, TrialState] = nf_trial_success_criterion_met(Measure, TrialState, RTConfig);
    if ~isempty(Logger)
        nf_development_maybe_inject_failure(RTConfig, ...
            Modes.DevelopmentFailure.LoggerAppend, Logger.NMeasures + 1);
        logMeasure = local_trial_log_measure(Measure, TrialResult.FirstTrialSample);
        Logger = nf_logger_append_measure(Logger, logMeasure);
        Logger = local_maybe_save_partial(Logger, Modes.Session.LiveTrial, RTConfig, 'cadence');
    end

    Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState);
    if Stop.ShouldStop
        TrialResult.StopReason = Stop.Reason;
        break;
    end
end

if isempty(TrialResult.StopReason)
    if useMaxDurationFailsafe
        LoopState.HardFailsafeExceeded = true;
        Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState);
        TrialResult.StopReason = Stop.Reason;
    else
        TrialResult.StopReason = Modes.StopReason.CompletedUnknown;
    end
end
Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.TrialStop, ...
    Modes.Phase.Trial, NaN, NaN, TrialResult.StopReason, ...
    strcmp(TrialResult.StopReason, Modes.StopReason.Error));
catch ME
    LoopState.ErrorOccurred = true;
    LoopState.LastError = ME.message;
    TrialResult.StopReason = Modes.StopReason.Error;
    TrialResult = local_record_error(TrialResult, ME);
    Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.TrialStop, ...
        Modes.Phase.Trial, NaN, NaN, TrialResult.StopReason, true);
end

%% ===== CLOSE FEEDBACK AND FINALIZE RESULT =====
if LoopState.ErrorOccurred || ~isempty(TrialResult.Error)
    TrialResult.Partial = true;
    Logger = local_attempt_partial_save(Logger, Modes.Session.LiveTrial, 'error');
end
TrialResult.PartialLogPaths = local_partial_paths(Logger);

TrialResult.NChunks = LoopState.NChunks;
TrialResult.NEmptyChunks = LoopState.NEmptyChunks;
TrialResult.NTimeouts = LoopState.NTimeouts;
TrialResult.TimeoutLimitExceeded = LoopState.TimeoutLimitExceeded;
TrialResult.NValidMeasures = LoopState.NValidMeasures;
TrialResult.NInvalidMeasures = LoopState.NInvalidMeasures;
TrialResult.NFeedbackUpdates = TrialState.NFeedbackUpdates;
TrialResult.NFeedbackLatencyWarnings = LoopState.NFeedbackLatencyWarnings;
TrialResult.DurationSeconds = LoopState.ElapsedSeconds;
TrialResult.LastChunkStatus = LoopState.LastChunkStatus;
TrialResult = local_attach_latency_summary(TrialResult, feedbackLatencies, RTConfig);
TrialResult.SafetySummary = local_safety_summary(Safety);
TrialResult.FeedbackAudit = local_feedback_audit(Feedback, RTConfig, feedbackLatencies);

[Feedback, cleanupMessages, feedbackClosed] = local_cleanup_feedback(Feedback);
TrialResult.FeedbackClosed = feedbackClosed;
[safetyMessages, safetyClosed] = local_cleanup_safety(Safety, RTConfig);
TrialResult.SafetyClosed = safetyClosed;
cleanupMessages = [cleanupMessages, safetyMessages];
if ownsLogger
    [Logger, loggerMessages, loggerClosed] = local_cleanup_logger(Logger);
    TrialResult.LoggerClosed = loggerClosed;
    cleanupMessages = [cleanupMessages, loggerMessages];
else
    TrialResult.LoggerClosed = false;
end
TrialResult.CleanupMessages = cleanupMessages;
for iMessage = 1:numel(cleanupMessages)
    Timeline = local_timeline_append(Timeline, Modes.TimelineEvent.CleanupError, ...
        Modes.Phase.Trial, NaN, NaN, cleanupMessages{iMessage}, true);
end

% Stop-file is an operator/manual stop, not an error abort. A stop-file trial
% can still count as completed when the configured data/feedback checks pass.
badStop = any(strcmp(TrialResult.StopReason, ...
    {Modes.StopReason.Error, Modes.StopReason.Timeout, Modes.StopReason.HardFailsafe}));
validPass = ~RTConfig.LiveTrial.RequireAtLeastOneValidMeasure || TrialResult.NValidMeasures >= 1;
feedbackPass = ~RTConfig.LiveTrial.RequireAtLeastOneFeedbackUpdate || TrialResult.NFeedbackUpdates >= 1;
latencyFail = RTConfig.Feedback.FailOnLatencyBudgetExceeded && ...
    LoopState.FeedbackLatencyBudgetExceeded;

TrialResult.Pass = TrialResult.Started && isempty(TrialResult.Error) && ~badStop && ...
    validPass && feedbackPass && TrialResult.NFiniteZSmoothed >= 1 && ...
    TrialResult.FeedbackClosed && ~latencyFail;
TrialResult.Completed = TrialResult.Pass || ~badStop;
if TrialResult.Completed && isempty(TrialResult.Error)
    TrialResult.Partial = false;
end

end

function Result = local_empty_trial_result(RTConfig)
% Create stable trial result schema.
Result = struct();
Result.Started = false;
Result.Completed = false;
Result.Partial = false;
Result.Pass = false;
Result.StopReason = '';
Result.NChunks = 0;
Result.NEmptyChunks = 0;
Result.NTimeouts = 0;
Result.MaxTimeouts = RTConfig.LiveTrial.MaxTimeouts;
Result.TimeoutLimitExceeded = false;
Result.NValidMeasures = 0;
Result.NInvalidMeasures = 0;
Result.NFiniteZRaw = 0;
Result.NFiniteZClipped = 0;
Result.NFiniteZSmoothed = 0;
Result.NFeedbackUpdates = 0;
Result.FeedbackClosed = false;
Result.LoggerClosed = false;
Result.SafetyClosed = false;
Result.TargetBand = [NaN NaN];
Result.TargetBandLabel = '';
Result.FeedbackMode = '';
Result.FeedbackBackend = '';
Result.FeedbackMapSource = '';
Result.FeedbackLatencyBudgetMs = NaN;
Result.FeedbackLatencyMsMean = NaN;
Result.FeedbackLatencyMsMedian = NaN;
Result.FeedbackLatencyMsP95 = NaN;
Result.FeedbackLatencyConfiguredPercentileMs = NaN;
Result.FeedbackLatencyMsMax = NaN;
Result.FeedbackLatencyPercentile = NaN;
Result.FeedbackLatencyMsValues = [];
Result.NFeedbackLatencyWarnings = 0;
Result.ManualStartResult = struct();
Result.SourceResyncInfo = struct();
Result.FirstTrialSample = NaN;
Result.LastTrialSample = NaN;
Result.FreshSamplesBeforeFirstValidMeasure = NaN;
Result.FirstValidMeasureWindowEndSample = NaN;
Result.FirstFeedbackUpdateWindowEndSample = NaN;
Result.FeedbackAudit = struct();
Result.SafetySummary = struct();
Result.PartialLogPaths = {};
Result.CleanupMessages = {};
Result.DurationSeconds = 0;
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
Result.BaselineConfigHash = '';
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
if isfield(RTConfig, 'LiveTrial') && isfield(RTConfig.LiveTrial, 'SavePartialEveryNMeasures')
    cadence = RTConfig.LiveTrial.SavePartialEveryNMeasures;
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

function [Feedback, messages, closed] = local_cleanup_feedback(Feedback)
% Close feedback without masking the original error.
messages = {};
closed = true;
if isempty(Feedback)
    return;
end
try
    Feedback = nf_feedback_close(Feedback);
    closed = ~local_logical_field(Feedback, 'IsOpen', false);
catch ME
    closed = false;
    messages{end+1} = sprintf('Feedback cleanup failed: %s', ME.message);
end
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

function TrialState = local_init_trial_state()
% Initialize the canonical trial state.
TrialState = struct();
TrialState.SuccessConsecutiveCount = 0;
TrialState.SuccessMet = false;
TrialState.NFeedbackUpdates = 0;
TrialState.NValidMeasures = 0;
TrialState.StartedAt = local_now_text();
TrialState.LastSuccessValue = NaN;
TrialState.LastSuccessField = '';
end

function LoopState = local_update_latency_state(LoopState, latencyMs, RTConfig)
% Record feedback latency-budget warnings.
exceeded = latencyMs > RTConfig.Feedback.LatencyBudgetMs;
if exceeded
    LoopState.NFeedbackLatencyWarnings = LoopState.NFeedbackLatencyWarnings + 1;
    LoopState.NConsecutiveFeedbackLatencyWarnings = LoopState.NConsecutiveFeedbackLatencyWarnings + 1;
else
    LoopState.NConsecutiveFeedbackLatencyWarnings = 0;
end
LoopState.FeedbackLatencyBudgetExceeded = ...
    LoopState.NConsecutiveFeedbackLatencyWarnings >= RTConfig.Feedback.MaxConsecutiveLatencyWarnings;
end

function Result = local_attach_latency_summary(Result, values, RTConfig)
% Attach latency summary fields.
Result.FeedbackLatencyPercentile = RTConfig.Feedback.LatencySummary.Percentile;
Result.FeedbackLatencyMsValues = values(:)';
if isempty(values)
    return;
end
values = sort(values(:));
Result.FeedbackLatencyMsMean = mean(values);
Result.FeedbackLatencyMsMedian = median(values);
Result.FeedbackLatencyConfiguredPercentileMs = local_percentile(values, ...
    RTConfig.Feedback.LatencySummary.Percentile);
Result.FeedbackLatencyMsP95 = local_true_p95(values);
Result.FeedbackLatencyMsMax = max(values);
end

function Audit = local_feedback_audit(Feedback, RTConfig, latencyValues)
% Capture display and flip evidence before feedback cleanup clears handles.
Audit = struct();
Audit.DisplayMode = RTConfig.DevelopmentSession.DisplayMode;
Audit.Backend = local_field(Feedback, 'Backend', '');
Audit.DevelopmentDisplay = RTConfig.DevelopmentSession.Enabled;
Audit.UsesRealPsychtoolbox = local_logical_field(Feedback, 'UsesRealPsychtoolbox', false);
Audit.UsesHeadlessPsychtoolboxTest = ...
    local_logical_field(Feedback, 'UsesHeadlessPsychtoolboxTest', false);
Audit.ScreenNumber = local_field(Feedback, 'ScreenNumber', NaN);
Audit.AvailableScreens = local_field(Feedback, 'AvailableScreens', []);
Audit.WindowRect = local_field(Feedback, 'WindowRect', []);
Audit.FlipAudit = local_field(Feedback, 'FlipAudit', struct([]));
Audit.NFlipRequests = numel(Audit.FlipAudit);
Audit.NCompletedFlips = sum(arrayfun(@local_flip_is_complete, Audit.FlipAudit));
Audit.NMissedFlips = sum(arrayfun(@local_deadline_missed_value, Audit.FlipAudit));
Audit.LatencyPercentile = RTConfig.Feedback.LatencySummary.Percentile;
Audit.LatencyValuesMs = latencyValues(:)';
Audit.LatencyMeanMs = NaN;
Audit.LatencyMedianMs = NaN;
Audit.LatencyP95Ms = NaN;
Audit.LatencyConfiguredPercentileMs = NaN;
Audit.LatencyMaxMs = NaN;
if ~isempty(latencyValues)
    Audit.LatencyMeanMs = mean(latencyValues);
    Audit.LatencyMedianMs = median(latencyValues);
    sortedValues = sort(latencyValues(:));
    Audit.LatencyConfiguredPercentileMs = local_percentile(sortedValues, ...
        RTConfig.Feedback.LatencySummary.Percentile);
    Audit.LatencyP95Ms = local_true_p95(sortedValues);
    Audit.LatencyMaxMs = max(latencyValues);
end
end

function tf = local_flip_is_complete(flip)
% Count completion only when the three Screen timestamps are finite scalars.
fields = {'VBLTimestamp','StimulusOnsetTime','FlipTimestamp'};
tf = all(isfield(flip, fields));
if ~tf
    return;
end
for iField = 1:numel(fields)
    value = flip.(fields{iField});
    tf = tf && local_is_finite_real_numeric_scalar(value);
end
end

function value = local_deadline_missed_value(flip)
% Count only positive validated Psychtoolbox deadline estimates.
value = 0;
if ~isfield(flip, 'Missed') || ...
        ~local_is_finite_real_numeric_scalar(flip.Missed)
    return;
end
value = double(flip.Missed > 0);
end

function tf = local_is_finite_real_numeric_scalar(value)
tf = isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value);
end

function value = local_true_p95(values)
% Latency fields labeled P95 always retain true 95th-percentile semantics.
value = local_percentile(values, 95);
end

function value = local_percentile(values, pct)
% Compute percentile without Statistics Toolbox.
if numel(values) == 1
    value = values(1);
    return;
end
% Convert the configured percentage to a unit interpolation fraction.
pos = 1 + (pct ./ 100) .* (numel(values) - 1);
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    value = values(lo);
else
    value = values(lo) .* (hi - pos) + values(hi) .* (pos - lo);
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

function Measure = local_trial_log_measure(Measure, firstTrialSample)
% Do not log hypothetical warmup-window indices before the fresh trial.
sampleFields = {'WindowStartSample','WindowCenterSample', ...
    'CorrectedWindowStartSample','CorrectedWindowCenterSample'};
for iField = 1:numel(sampleFields)
    fieldName = sampleFields{iField};
    if isfield(Measure, fieldName) && isfinite(Measure.(fieldName)) && ...
            Measure.(fieldName) < firstTrialSample
        Measure.(fieldName) = NaN;
    end
end
if ~isfinite(Measure.CorrectedWindowCenterSample)
    Measure.NeuralWindowTime = NaN;
    Measure.Time = NaN;
end
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

function tf = local_use_max_duration_failsafe(RTConfig)
% Read the optional hard-failsafe enable flag.
tf = true;
if isfield(RTConfig, 'Safety') && isfield(RTConfig.Safety, 'UseMaxDurationFailsafe') && ...
        ~isempty(RTConfig.Safety.UseMaxDurationFailsafe)
    tf = logical(RTConfig.Safety.UseMaxDurationFailsafe);
end
end

function maxIterations = local_trial_max_iterations(RTConfig, useMaxDurationFailsafe)
% Resolve the trial loop cap without inventing a second failsafe duration.
if useMaxDurationFailsafe
    maxIterations = max(1, ceil(RTConfig.Protocol.Trial.MaxFailsafeSeconds ./ RTConfig.ChunkSeconds));
    return;
end

maxIterations = Inf;
if isfield(RTConfig, 'LiveTrial') && isfield(RTConfig.LiveTrial, 'TestMaxIterations') && ...
        isnumeric(RTConfig.LiveTrial.TestMaxIterations) && ...
        isscalar(RTConfig.LiveTrial.TestMaxIterations) && ...
        isfinite(RTConfig.LiveTrial.TestMaxIterations) && ...
        RTConfig.LiveTrial.TestMaxIterations >= 1
    maxIterations = round(RTConfig.LiveTrial.TestMaxIterations);
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
