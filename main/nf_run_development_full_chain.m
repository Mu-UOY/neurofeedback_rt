function [SessionResult, Source, Spatial, Logger] = ...
    nf_run_development_full_chain(RTConfig)
% NF_RUN_DEVELOPMENT_FULL_CHAIN Run the Step 0 lifecycle harness.
%
% USAGE:  [SessionResult, Source, Spatial, Logger] = ...
%             nf_run_development_full_chain(RTConfig)

Modes = nf_modes();
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_development_session_config();
end
SessionResult = local_empty_result(Modes);
Source = [];
Spatial = [];
Logger = [];
Timeline = [];
sessionTic = tic;

try
    %% ===== FINALIZE CONFIG AND SESSION =====
    requestedRoot = local_nested(RTConfig, {'Paths','ProjectRoot'}, '');
    RTConfig = nf_finalize_config(RTConfig);
    if ~isempty(requestedRoot)
        RTConfig.Paths.ProjectRoot = requestedRoot;
    end
    if isempty(RTConfig.Source.FieldTrip.TestBufferFcn)
        RTConfig.Source.FieldTrip.TestBufferFcn = nf_make_development_fieldtrip_buffer(RTConfig);
    end
    Session = nf_make_session_output_dir(RTConfig, Modes.Session.DevelopmentFullChain);
    [~, runID] = fileparts(Session.SessionDir);
    SessionResult.RunID = runID;
    SessionResult.Started = true;
    SessionResult.StartedAt = local_now_text();
    SessionResult.SessionOutputDir = Session.SessionDir;
    SessionResult.TimelinePath = fullfile(Session.SessionDir, ...
        RTConfig.DevelopmentSession.Output.TimelineFilename);
    RTConfig.SessionMetadata.RunID = runID;
    RTConfig.Paths.BaselinesDir = Session.BaselineDir;
    RTConfig.Logging.ExistingSession = Session;
    Timeline = nf_development_timeline_init(RTConfig, Session.SessionDir);

    %% ===== PREPARE SHARED SOURCE, MATRIX, AND LOGGER =====
    Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
    local_validate_source(Source, RTConfig);
    readiness = local_nested(Source, {'BlockInfo'}, struct());
    SessionResult.SourceSummary = local_source_summary(Source, readiness);
    SessionResult.SourceReady = local_readiness_is_valid(readiness, Modes);
    if ~SessionResult.SourceReady
        error('neurofeedback:developmentSourceNotReady', ...
            'Step 0 source readiness did not prove positive sample advancement.');
    end
    Timeline = nf_development_timeline_append(Timeline, ...
        Modes.TimelineEvent.SourceReady, '', readiness.InitialNSamples, ...
        readiness.SecondNSamples, 'Development FieldTrip source advancement passed.', false);

    Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);
    local_validate_spatial(Spatial, RTConfig, Modes);
    SessionResult.SpatialSummary = local_spatial_summary(Spatial);
    Timeline = nf_development_timeline_append(Timeline, ...
        Modes.TimelineEvent.SpatialReady, '', NaN, NaN, ...
        'Representative technical matrix ready.', false);

    RTConfig.Spatial.CombinedMatrix = Spatial.CombinedMatrix;
    RTConfig.Spatial.NChannels = size(Spatial.CombinedMatrix, 2);
    RTConfig.Spatial.Prepared = Spatial;
    Logger = nf_logger_init(RTConfig, Modes.Session.DevelopmentFullChain, Source);
    Timeline = nf_development_timeline_append(Timeline, ...
        Modes.TimelineEvent.LoggerReady, '', NaN, NaN, 'Shared logger ready.', false);

    %% ===== RESTING AND BASELINE RELOAD =====
    SessionResult.CurrentPhase = Modes.Phase.Resting;
    restingConfig = RTConfig;
    restingConfig.PhaseRunner.ManualStartOwner = Modes.PhaseRunnerOwner.Internal;
    restingConfig.PhaseRunner.ResyncOwner = Modes.PhaseRunnerOwner.Internal;
    [Baseline, RestingResult, Source, Logger, Timeline] = ...
        nf_run_live_resting(restingConfig, Source, Spatial, Logger, Timeline);
    SessionResult.RestingResult = RestingResult;
    SessionResult.CleanupMessages = [SessionResult.CleanupMessages, ...
        local_nested(RestingResult, {'CleanupMessages'}, {})];
    if ~RestingResult.Pass
        local_raise_phase_error(RestingResult, 'Step 0 resting phase failed.');
    end
    SessionResult.BaselineQuality = RestingResult.BaselineQuality;
    SessionResult.BaselinePath = RestingResult.BaselinePath;
    loadConfig = RTConfig;
    loadConfig.Baseline.Path = SessionResult.BaselinePath;
    loadConfig.Feedback.Mode = Baseline.ConfigHashInputs.FeedbackMode;
    ReloadedBaseline = nf_load_baseline(loadConfig);
    SessionResult.BaselineReloaded = true;
    SessionResult.BaselineConfigHash = local_nested( ...
        ReloadedBaseline, {'ConfigHash'}, '');
    Timeline = nf_development_timeline_append(Timeline, ...
        Modes.TimelineEvent.BaselineReloaded, Modes.Phase.Resting, NaN, NaN, ...
        'Baseline reloaded through nf_load_baseline.', false);

    %% ===== BOUNDED TRANSITION =====
    SessionResult.CurrentPhase = Modes.Phase.Transition;
    [TransitionResult, Source, Timeline] = ...
        nf_run_development_transition(RTConfig, Source, Timeline);
    SessionResult.TransitionResult = TransitionResult;
    if ~TransitionResult.Pass
        SessionResult.StopReason = TransitionResult.StopReason;
        if strcmp(TransitionResult.StopReason, Modes.StopReason.TransitionTimeout)
            error('neurofeedback:developmentTransitionTimeout', ...
                'Step 0 transition exceeded its configured maximum wait.');
        end
        local_raise_phase_error(TransitionResult, ...
            'Step 0 transition did not complete.');
    end

    %% ===== FRESH TRIAL =====
    SessionResult.CurrentPhase = Modes.Phase.Trial;
    trialConfig = RTConfig;
    trialConfig.PhaseRunner.ManualStartOwner = Modes.PhaseRunnerOwner.External;
    trialConfig.PhaseRunner.ResyncOwner = Modes.PhaseRunnerOwner.External;
    [TrialResult, Source, Logger, Timeline] = nf_run_live_trial( ...
        trialConfig, Source, Spatial, ReloadedBaseline, Logger, Timeline);
    SessionResult.TrialResult = TrialResult;
    SessionResult.FeedbackAudit = TrialResult.FeedbackAudit;
    SessionResult.CleanupMessages = [SessionResult.CleanupMessages, ...
        local_nested(TrialResult, {'CleanupMessages'}, {})];
    SessionResult.TrialBaselineConfigHash = local_nested( ...
        TrialResult, {'BaselineConfigHash'}, '');
    if isempty(SessionResult.BaselineConfigHash) || ...
            ~strcmp(SessionResult.TrialBaselineConfigHash, ...
                SessionResult.BaselineConfigHash)
        error('neurofeedback:developmentBaselineIdentityMismatch', ...
            'Trial did not use the baseline reloaded for this session.');
    end
    if ~TrialResult.Pass
        local_raise_phase_error(TrialResult, 'Step 0 trial phase failed.');
    end
    local_validate_trial_warmup(TrialResult, TransitionResult, RTConfig);
    SessionResult.SpatialSummary = local_validate_phase_spatial( ...
        SessionResult.SpatialSummary, RestingResult, TrialResult, Spatial);
    nf_validate_development_feedback_audit( ...
        SessionResult.FeedbackAudit, TrialResult, RTConfig, Modes);

    %% ===== FINALIZE SUCCESS =====
    SessionResult.CurrentPhase = '';
    SessionResult.StopReason = TrialResult.StopReason;
    nf_development_maybe_inject_failure(RTConfig, ...
        Modes.DevelopmentFailure.LoggerClose, 1);
    Logger = nf_logger_close(Logger);
    SessionResult.LoggerClosed = Logger.Closed;
    SessionResult.Pass = true;
    SessionResult.Completed = true;
    SessionResult.Partial = false;
    SessionResult.OverallStatus = Modes.DevelopmentStatus.Pass;
catch ME
    SessionResult = local_record_primary_error(SessionResult, ME, Modes);
    if ~isempty(Timeline)
        try
            Timeline = nf_development_timeline_append(Timeline, ...
                Modes.TimelineEvent.PrimaryError, SessionResult.CurrentPhase, ...
                NaN, NaN, ME.message, true);
        catch TimelineME
            SessionResult.CleanupMessages{end + 1} = TimelineME.message;
        end
    end
end

%% ===== INDEPENDENT CLEANUP AND DURABLE REPORT =====
if ~isempty(Timeline)
    try
        Timeline = nf_development_timeline_append(Timeline, ...
            Modes.TimelineEvent.CleanupStart, '', NaN, NaN, 'Cleanup started.', false);
    catch ME
        SessionResult.CleanupMessages{end + 1} = ME.message;
    end
end
if ~isempty(Logger) && (~isfield(Logger, 'Closed') || ~Logger.Closed)
    try
        Logger = nf_logger_close(Logger);
        SessionResult.LoggerClosed = Logger.Closed;
    catch ME
        SessionResult.CleanupMessages{end + 1} = sprintf('Logger cleanup failed: %s', ME.message);
        if ~isempty(Timeline)
            try
                Timeline = nf_development_timeline_append(Timeline, ...
                    Modes.TimelineEvent.CleanupError, '', NaN, NaN, ME.message, true);
            catch
            end
        end
    end
end
if ~SessionResult.LoggerClosed
    SessionResult.Pass = false;
end
SessionResult.EndedAt = local_now_text();
SessionResult.DurationSeconds = toc(sessionTic);
if SessionResult.Started && ~SessionResult.Pass
    SessionResult.Completed = false;
    SessionResult.Partial = true;
    SessionResult.OverallStatus = Modes.DevelopmentStatus.Partial;
end
if ~isempty(Timeline)
    try
        Timeline = nf_development_timeline_append(Timeline, ...
            Modes.TimelineEvent.CleanupEnd, '', NaN, NaN, 'Cleanup completed.', false);
        Timeline = nf_development_timeline_append(Timeline, ...
            Modes.TimelineEvent.SessionComplete, '', NaN, NaN, ...
            SessionResult.OverallStatus, ~SessionResult.Pass);
        SessionResult.TimelinePath = Timeline.Path;
    catch ME
        SessionResult.CleanupMessages{end + 1} = sprintf('Timeline cleanup failed: %s', ME.message);
        SessionResult.Pass = false;
        SessionResult.Completed = false;
        SessionResult.Partial = true;
        SessionResult.OverallStatus = Modes.DevelopmentStatus.Partial;
    end
end
if SessionResult.Started
    try
        SessionResult = nf_save_development_session_report(SessionResult, RTConfig);
    catch ME
        SessionResult.CleanupMessages{end + 1} = sprintf('Session report failed: %s', ME.message);
        SessionResult.Pass = false;
        SessionResult.Completed = false;
        SessionResult.Partial = true;
        SessionResult.OverallStatus = Modes.DevelopmentStatus.Partial;
    end
end

end

function Result = local_empty_result(Modes)
Result = struct('RunID','','Started',false,'Completed',false,'Partial',false, ...
    'Pass',false,'OverallStatus',Modes.DevelopmentStatus.Fail, ...
    'DevelopmentOnly',true,'ProductionEquivalent',false,'CurrentPhase','', ...
    'StopReason','','StartedAt','','EndedAt','','DurationSeconds',0, ...
    'SessionOutputDir','','SourceReady',false,'SourceSummary',struct(), ...
    'SpatialSummary',struct(),'RestingResult',struct(),'BaselinePath','', ...
    'BaselineReloaded',false,'BaselineConfigHash','', ...
    'TrialBaselineConfigHash','','BaselineQuality',struct(), ...
    'TransitionResult',struct(),'TrialResult',struct(),'FeedbackAudit',struct(), ...
    'SummaryPath','','SummaryCsvPath','','TimelinePath','', ...
    'PartialReportPath','','PartialReportCsvPath','','LoggerClosed',false, ...
    'CleanupMessages',{{}},'Error','','ErrorIdentifier','','ErrorReport','');
end

function Result = local_record_primary_error(Result, ME, Modes)
if isempty(Result.Error)
    Result.Error = ME.message;
    Result.ErrorIdentifier = ME.identifier;
    try
        Result.ErrorReport = getReport(ME, 'extended', 'hyperlinks', 'off');
    catch
        Result.ErrorReport = ME.message;
    end
end
Result.Pass = false;
Result.Completed = false;
Result.Partial = Result.Started;
if Result.Started
    Result.OverallStatus = Modes.DevelopmentStatus.Partial;
else
    Result.OverallStatus = Modes.DevelopmentStatus.Fail;
end
end

function local_raise_phase_error(Result, fallbackMessage)
identifier = local_nested(Result, {'ErrorIdentifier'}, '');
message = local_nested(Result, {'Error'}, fallbackMessage);
if isempty(identifier)
    identifier = 'neurofeedback:developmentPhaseFailed';
end
if isempty(message)
    message = fallbackMessage;
end
error(identifier, '%s', message);
end

function local_validate_source(Source, RTConfig)
expectedNames = [nf_ctf275_primary_channel_names(), ...
    nf_step0_provisional_reference_channel_names(RTConfig)];
if Source.Fs ~= RTConfig.Fs || numel(Source.ChannelNames) ~= numel(expectedNames) || ...
        ~isequal(Source.ChannelNames, expectedNames)
    error('Step 0 development source header validation failed.');
end
end

function local_validate_spatial(Spatial, RTConfig, Modes)
expectedSize = [RTConfig.DevelopmentSession.Matrix.OutputRowUpperBound, ...
    RTConfig.DevelopmentSession.Input.TotalChannelCount];
if ~isequal(size(Spatial.CombinedMatrix), expectedSize) || Spatial.IsIPS || ...
        ~Spatial.IsTechnicalFallback || ...
        ~strcmp(Spatial.FallbackType, Modes.Spatial.FallbackType.RepresentativeDense)
    error('Step 0 representative technical matrix validation failed.');
end
end

function local_validate_trial_warmup(Trial, Transition, RTConfig)
if Transition.SkippedSampleCount > 0
    expectedFirst = Transition.SkippedLastSample + 1;
else
    expectedFirst = Transition.PreviousSample + 1;
end
if Trial.FirstTrialSample ~= expectedFirst || ...
        Trial.LastTrialSample < Trial.FirstTrialSample || ...
        Trial.FirstValidMeasureWindowEndSample < ...
        Trial.FirstTrialSample + RTConfig.PowerWindowSamples - 1 || ...
        Trial.FirstValidMeasureWindowEndSample > Trial.LastTrialSample || ...
        Trial.FirstFeedbackUpdateWindowEndSample < Trial.FirstValidMeasureWindowEndSample || ...
        Trial.FirstFeedbackUpdateWindowEndSample > Trial.LastTrialSample
    error('Step 0 fresh-trial warm-up contract failed.');
end
end

function Summary = local_validate_phase_spatial(Summary, Resting, Trial, Spatial)
% Compare independent phase-reported spatial identities to the session object.
phaseHashes = {Resting.SpatialHash, Trial.SpatialHash};
if any(~strcmp(phaseHashes, Spatial.Hash)) || ...
        ~isequal(Resting.SpatialSize, size(Spatial.CombinedMatrix)) || ...
        ~isequal(Trial.SpatialSize, size(Spatial.CombinedMatrix)) || ...
        ~strcmp(Resting.SpatialMatrixSource, Spatial.MatrixSource) || ...
        ~strcmp(Trial.SpatialMatrixSource, Spatial.MatrixSource) || ...
        ~Resting.SpatialIsTechnicalFallback || ~Trial.SpatialIsTechnicalFallback || ...
        Resting.SpatialIsIPS || Trial.SpatialIsIPS || ...
        ~isequal(Resting.SpatialInputChannelNames, Spatial.InputChannelNames) || ...
        ~isequal(Trial.SpatialInputChannelNames, Spatial.InputChannelNames)
    error('neurofeedback:developmentSpatialIdentityMismatch', ...
        'Resting/trial spatial identity does not match the session matrix.');
end
Summary.RestingHash = Resting.SpatialHash;
Summary.TrialHash = Trial.SpatialHash;
Summary.SameHashAcrossPhases = strcmp(Resting.SpatialHash, Trial.SpatialHash);
end

function Summary = local_source_summary(Source, Readiness)
Summary = struct('Fs',Source.Fs,'NChannels',numel(Source.ChannelNames), ...
    'InitialSample',Source.InitialSample,'HeaderFingerprint',Source.HeaderFingerprint, ...
    'InitialNSamples',local_nested(Readiness, {'InitialNSamples'}, NaN), ...
    'LaterNSamples',local_nested(Readiness, {'SecondNSamples'}, NaN), ...
    'AdvancementCount',local_nested(Readiness, {'AdvancementCount'}, NaN), ...
    'ReadinessPass',local_nested(Readiness, {'Pass'}, false), ...
    'ReadinessStatus',local_nested(Readiness, {'Status'}, ''));
end

function Summary = local_spatial_summary(Spatial)
Summary = struct('Hash',Spatial.Hash,'Size',size(Spatial.CombinedMatrix), ...
    'NumericClass',class(Spatial.CombinedMatrix),'RequestedDensity',Spatial.RequestedDensity, ...
    'RealizedDensity',Spatial.RealizedDensity,'Orientation',Spatial.Orientation, ...
    'MatrixSource',Spatial.MatrixSource,'InputChannelNames',{Spatial.InputChannelNames}, ...
    'IsIPS',Spatial.IsIPS,'IsTechnicalFallback',Spatial.IsTechnicalFallback);
end

function tf = local_readiness_is_valid(Readiness, Modes)
% Accept only complete, finite, positive source-advancement evidence.
required = {'InitialNSamples','SecondNSamples','SampleCountAdvanced', ...
    'AdvancementCount','Pass','Status'};
tf = isstruct(Readiness) && isscalar(Readiness) && all(isfield(Readiness, required));
if ~tf
    return;
end
flagsAreScalar = isscalar(Readiness.SampleCountAdvanced) && ...
    isscalar(Readiness.Pass) && ...
    (islogical(Readiness.SampleCountAdvanced) || isnumeric(Readiness.SampleCountAdvanced)) && ...
    (islogical(Readiness.Pass) || isnumeric(Readiness.Pass));
tf = local_is_finite_scalar(Readiness.InitialNSamples) && ...
    local_is_finite_scalar(Readiness.SecondNSamples) && ...
    local_is_finite_scalar(Readiness.AdvancementCount) && flagsAreScalar && ...
    Readiness.AdvancementCount > 0 && ...
    Readiness.SecondNSamples > Readiness.InitialNSamples && ...
    logical(Readiness.SampleCountAdvanced) && logical(Readiness.Pass) && ...
    (ischar(Readiness.Status) || isstring(Readiness.Status)) && ...
    strcmp(char(Readiness.Status), Modes.ReadinessStatus.Pass);
end

function tf = local_is_finite_scalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value);
end

function value = local_nested(S, path, defaultValue)
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
value = cursor;
end

function value = local_now_text()
value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
