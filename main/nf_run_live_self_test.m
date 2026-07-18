function Result = nf_run_live_self_test(RTConfig)
% NF_RUN_LIVE_SELF_TEST Run the Step 3D live MEG feedback self-test.
%
% USAGE:  Result = nf_run_live_self_test()
%         Result = nf_run_live_self_test(RTConfig)

%% ===== PREPARE CONFIG =====
% Production defaults keep the real FieldTrip path and no test hook.
Modes = nf_modes();
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_live_config();
end
RTConfig.Session.Mode = Modes.Session.LiveSelfTest;
RTConfig.Source.Mode = Modes.Source.LiveFieldTrip;
RTConfig.Source.LiveAdapter = Modes.LiveAdapter.BenFieldTrip;

requestedProjectRoot = '';
if isfield(RTConfig, 'Paths') && isfield(RTConfig.Paths, 'ProjectRoot')
    requestedProjectRoot = RTConfig.Paths.ProjectRoot;
end
RTConfig = nf_finalize_config(RTConfig);
if ~isempty(requestedProjectRoot)
    RTConfig.Paths.ProjectRoot = requestedProjectRoot;
    RTConfig.Paths.BaselinesDir = fullfile(requestedProjectRoot, 'outputs', 'baselines');
    RTConfig.Paths.TrialsDir = fullfile(requestedProjectRoot, 'outputs', 'trials');
end

Result = local_empty_result();
Result.RunID = local_run_id();
Result.Started = true;
RTConfig.SessionMetadata.RunID = Result.RunID;

Source = [];
Spatial = [];
Baseline = [];
RestingResult = struct();
TrialResult = local_empty_trial_result();
Logger = [];

%% ===== RUN SELF-TEST =====
% Each stage saves enough state for the final audit report.
try
    Result.Preflight = local_run_preflight(RTConfig);
    if Result.Preflight.Ran && ~Result.Preflight.Pass
        Result.StopReason = 'preflight_failed';
        Result.Recommendation = 'Resolve requested preflight failures before live self-test.';
        Result = local_finalize_result(Result, RTConfig, RestingResult, TrialResult);
        Result = nf_save_live_self_test(Result, RTConfig, Source, Spatial, Baseline, RestingResult, TrialResult);
        return;
    end

    Source = nf_source_init(Modes.Source.LiveFieldTrip, [], RTConfig);
    local_check_source(Source);
    Result.SourceSummary = local_source_summary(Source, RTConfig);

    Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);
    Result.SpatialSummary = local_spatial_summary(Spatial);

    Logger = nf_logger_init(RTConfig, Modes.Session.LiveSelfTest, Source);

    [Baseline, RestingResult, Source, Logger] = nf_run_live_resting(RTConfig, Source, Spatial, Logger);
    Result.BaselinePath = local_field(RestingResult, 'BaselinePath', '');

    if RTConfig.LiveSelfTest.RequireRestingPass && ~RestingResult.Pass
        Result.StopReason = RestingResult.StopReason;
        Result.Recommendation = 'Fix baseline validity/quality before live trial.';
    else
        [TrialResult, Source, Logger] = nf_run_live_trial(RTConfig, Source, Spatial, Baseline, Logger);
        Result.StopReason = TrialResult.StopReason;
    end
catch ME
    Result = local_record_error(Result, ME);
    Result.StopReason = Modes.StopReason.Error;
    Logger = local_attempt_partial_save(Logger, Modes.Session.LiveSelfTest, 'error');
end

%% ===== CLEANUP AND SAVE =====
% Logger close is idempotent and does not own feedback display resources.
cleanupMessages = {};
try
    if ~isempty(Logger)
        Logger = nf_logger_close(Logger);
        Result.LoggerClosed = local_logical_field(Logger, 'Closed', false);
        Result.PartialLogPaths = local_partial_paths(Logger);
    else
        Result.LoggerClosed = true;
    end
catch ME
    Result.LoggerClosed = false;
    cleanupMessages{end+1} = sprintf('Logger cleanup failed: %s', ME.message);
    if isempty(Result.Error)
        Result = local_record_error(Result, ME);
    end
end
Result.FeedbackClosed = local_logical_field(TrialResult, 'FeedbackClosed', true);
if isfield(TrialResult, 'CleanupMessages') && iscell(TrialResult.CleanupMessages)
    cleanupMessages = [cleanupMessages, TrialResult.CleanupMessages];
end
if isfield(RestingResult, 'CleanupMessages') && iscell(RestingResult.CleanupMessages)
    cleanupMessages = [cleanupMessages, RestingResult.CleanupMessages];
end
Result.CleanupMessages = cleanupMessages;

Result.RestingResult = RestingResult;
Result.TrialResult = TrialResult;
Result = local_finalize_result(Result, RTConfig, RestingResult, TrialResult);
Result = nf_save_live_self_test(Result, RTConfig, Source, Spatial, Baseline, RestingResult, TrialResult);

end

function Result = local_empty_result()
% Create stable self-test result schema.
Result = struct();
Result.Started = false;
Result.Completed = false;
Result.Partial = false;
Result.Pass = false;
Result.RunID = '';
Result.OutputDir = '';
Result.SourceSummary = struct();
Result.SpatialSummary = struct();
Result.Preflight = local_empty_preflight();
Result.RestingResult = struct();
Result.TrialResult = struct();
Result.BaselinePath = '';
Result.FeedbackClosed = true;
Result.LoggerClosed = false;
Result.PartialLogPaths = {};
Result.CleanupMessages = {};
Result.StopReason = '';
Result.Error = '';
Result.ErrorIdentifier = '';
Result.ErrorReport = '';
Result.Recommendation = '';
Result.ReportMatPath = '';
Result.ReportTextPath = '';
Result.ConfigPath = '';
Result.SummaryCsvPath = '';
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

function Preflight = local_empty_preflight()
% Create stable preflight schema.
Preflight = struct();
Preflight.Type = 'preflight_result';
Preflight.Ran = false;
Preflight.FlagsRequested = struct();
Preflight.PerCheckResults = {};
Preflight.Pass = true;
Preflight.Error = '';
end

function TrialResult = local_empty_trial_result()
% Minimal empty trial result used when resting stops the self-test.
TrialResult = struct();
TrialResult.Started = false;
TrialResult.Pass = false;
TrialResult.StopReason = '';
TrialResult.NFeedbackUpdates = 0;
TrialResult.FeedbackClosed = true;
TrialResult.NFiniteZSmoothed = 0;
TrialResult.Error = '';
end

function Preflight = local_run_preflight(RTConfig)
% Run optional preflight checks only when requested.
Preflight = local_empty_preflight();
flags = struct();
flags.RunPreflightDiagnostics = RTConfig.LiveSelfTest.RunPreflightDiagnostics;
flags.RunChannelCheck = RTConfig.LiveSelfTest.RunChannelCheck;
flags.RunChunkSmokeTest = RTConfig.LiveSelfTest.RunChunkSmokeTest;
flags.RunRTDryRun = RTConfig.LiveSelfTest.RunRTDryRun;
Preflight.FlagsRequested = flags;
Preflight.Ran = flags.RunPreflightDiagnostics || flags.RunChannelCheck || ...
    flags.RunChunkSmokeTest || flags.RunRTDryRun;
if ~Preflight.Ran
    return;
end

checks = {};
if flags.RunPreflightDiagnostics
    checks(end+1, :) = {'nf_run_live_diagnostics', 'diagnostics'}; %#ok<AGROW>
end
if flags.RunChannelCheck
    checks(end+1, :) = {'nf_run_live_channel_check', 'channel_check'}; %#ok<AGROW>
end
if flags.RunChunkSmokeTest
    checks(end+1, :) = {'nf_run_live_chunk_smoke_test', 'chunk_smoke_test'}; %#ok<AGROW>
end
if flags.RunRTDryRun
    checks(end+1, :) = {'nf_run_live_rt_dry_run', 'rt_dry_run'}; %#ok<AGROW>
end

Preflight.Pass = true;
for iCheck = 1:size(checks, 1)
    fcnName = checks{iCheck, 1};
    label = checks{iCheck, 2};
    if exist(fcnName, 'file') == 0
        error('Requested preflight runner does not exist: %s', fcnName);
    end
    record = struct('Name', label, 'Function', fcnName, 'Pass', false, ...
        'Result', [], 'Error', '');
    try
        record.Result = feval(fcnName, RTConfig);
        record.Pass = local_result_pass(record.Result);
    catch ME
        record.Error = ME.message;
        record.Pass = false;
    end
    Preflight.PerCheckResults{end+1} = record; %#ok<AGROW>
    Preflight.Pass = Preflight.Pass && record.Pass;
end
end

function tf = local_result_pass(value)
% Infer pass/fail from common result structs.
tf = true;
if isstruct(value) && isfield(value, 'Pass')
    tf = logical(value.Pass);
elseif isstruct(value) && isfield(value, 'Status')
    tf = strcmp(char(value.Status), 'PASS');
end
end

function local_check_source(Source)
% Fail early when live source header does not match Step 3 timing.
if ~isfield(Source, 'Fs') || abs(Source.Fs - 2400) > 1e-9
    error('Live self-test requires Source.Fs = 2400 Hz.');
end
if ~isfield(Source, 'ChannelNames') || isempty(Source.ChannelNames)
    error('Live self-test requires live channel labels.');
end
end

function Result = local_finalize_result(Result, RTConfig, RestingResult, TrialResult)
% Apply the explicit Step 3D pass formula.
preflightOK = ~Result.Preflight.Ran || Result.Preflight.Pass;
restingOK = ~RTConfig.LiveSelfTest.RequireRestingPass || ...
    (isstruct(RestingResult) && isfield(RestingResult, 'Pass') && RestingResult.Pass);
trialStartedOK = ~RTConfig.LiveSelfTest.RequireTrialStarted || ...
    (isstruct(TrialResult) && isfield(TrialResult, 'Started') && TrialResult.Started);
trialOK = isstruct(TrialResult) && isfield(TrialResult, 'Pass') && TrialResult.Pass;
feedbackOK = ~RTConfig.LiveSelfTest.RequireAtLeastOneFeedbackUpdate || ...
    (isstruct(TrialResult) && isfield(TrialResult, 'NFeedbackUpdates') && ...
    TrialResult.NFeedbackUpdates >= 1);
cleanupOK = Result.FeedbackClosed && Result.LoggerClosed;
noError = isempty(Result.Error);

Result.Pass = preflightOK && restingOK && trialStartedOK && trialOK && ...
    feedbackOK && cleanupOK && noError;
Result.Completed = noError && cleanupOK;
if Result.Completed
    Result.Partial = false;
end
if isempty(Result.Recommendation)
    Result.Recommendation = local_recommendation(Result, RestingResult, TrialResult);
end
end

function recommendation = local_recommendation(Result, RestingResult, TrialResult)
% Return a concise audit recommendation.
if Result.Pass && isfield(Result.SpatialSummary, 'IsTechnicalFallback') && ...
        Result.SpatialSummary.IsTechnicalFallback
    recommendation = 'Display/RT path passed, but TechnicalFallback is not IPS neurofeedback.';
elseif Result.Pass
    recommendation = 'First full live feedback self-test pass; repeat/review before participant use.';
elseif isstruct(RestingResult) && isfield(RestingResult, 'Pass') && ~RestingResult.Pass
    recommendation = 'Fix baseline validity/quality.';
elseif strcmp(local_field(Result, 'StopReason', ''), 'timeout')
    recommendation = 'Check buffer availability, timeout settings, and source cursor.';
elseif isstruct(TrialResult) && isfield(TrialResult, 'NFiniteZSmoothed') && TrialResult.NFiniteZSmoothed < 1
    recommendation = 'Check Baseline attachment/z-score/filter warmup/schema.';
elseif isstruct(TrialResult) && isfield(TrialResult, 'NFeedbackUpdates') && TrialResult.NFeedbackUpdates < 1
    recommendation = 'Check feedback mapping/display outside RT core.';
else
    recommendation = 'Review live self-test failure before proceeding.';
end
end

function Summary = local_source_summary(Source, RTConfig)
% Build source audit summary.
Summary = struct();
Summary.Mode = local_field(Source, 'Mode', local_get_nested_text(RTConfig, {'Source','Mode'}, ''));
Summary.LiveAdapter = local_field(Source, 'LiveAdapter', local_get_nested_text(RTConfig, {'Source','LiveAdapter'}, ''));
Summary.Fs = local_numeric_field(Source, 'Fs', NaN);
Summary.NChannels = local_numeric_field(Source, 'NChannels', numel(local_field(Source, 'ChannelNames', {})));
Summary.ChannelNames = local_field(Source, 'ChannelNames', {});
Summary.ChannelNamesAfterCorrection = local_field(Source, 'ChannelNamesAfterCorrection', {});
Summary.HeaderHash = local_field(Source, 'HeaderHash', '');
Summary.ResolvedConnection = local_field(Source, 'ResolvedConnection', struct());
end

function Summary = local_spatial_summary(Spatial)
% Build spatial audit summary.
Summary = struct();
Summary.MatrixSource = local_field(Spatial, 'MatrixSource', '');
Summary.IsIPS = local_logical_field(Spatial, 'IsIPS', false);
Summary.IsTechnicalFallback = local_logical_field(Spatial, 'IsTechnicalFallback', false);
Summary.NSignals = size(local_field(Spatial, 'CombinedMatrix', []), 1);
Summary.NChannels = size(local_field(Spatial, 'CombinedMatrix', []), 2);
Summary.Hash = local_field(Spatial, 'Hash', '');
Summary.Messages = local_field(Spatial, 'Messages', {});
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

function value = local_numeric_field(S, fieldName, defaultValue)
% Read optional numeric field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && isnumeric(S.(fieldName)) && ~isempty(S.(fieldName))
    value = double(S.(fieldName)(1));
end
end

function value = local_get_nested_text(S, path, defaultValue)
% Read optional nested text.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if ischar(cursor) || isstring(cursor)
    value = char(cursor);
end
end

function value = local_run_id()
% Generate compact run identifier.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
else
    value = datestr(now, 'yyyymmdd_HHMMSS');
end
end
