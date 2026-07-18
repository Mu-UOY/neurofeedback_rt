function Report = test_step0_artifact_readback(outputRoot)
% TEST_STEP0_ARTIFACT_READBACK Reopen and reconcile retained Step 0 outputs.

retainArtifacts = nargin >= 1 && ~isempty(outputRoot);
if ~retainArtifacts
    outputRoot = tempname;
end
if exist(outputRoot, 'dir') == 0
    mkdir(outputRoot);
end
if retainArtifacts
    cleanup = []; %#ok<NASGU>
else
    cleanup = onCleanup(@() local_remove_tree(outputRoot)); %#ok<NASGU>
end

Modes = nf_modes();
Report = struct('OutputRoot', outputRoot, 'Scenarios', struct([]), ...
    'Pass', false);

configs = cell(1, 5);
names = {'representative_success','positive_backlog','zero_backlog', ...
    'transition_timeout','injected_failure'};

configs{1} = nf_test_step0_config(fullfile(outputRoot, names{1}), true);

configs{2} = nf_test_step0_config(fullfile(outputRoot, names{2}));
configs{2}.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = ...
    configs{2}.DevelopmentSession.Transition.MaxPauseSeconds;

configs{3} = nf_test_step0_config(fullfile(outputRoot, names{3}));
configs{3}.DevelopmentSession.Transition.TestAdvanceChunks = 0;
configs{3} = local_refinalize_and_rebuild(configs{3});

configs{4} = nf_test_step0_config(fullfile(outputRoot, names{4}));
configs{4}.DevelopmentSession.TestHooks.ManualStartWaitDurationSeconds.Transition = ...
    configs{4}.DevelopmentSession.Transition.MaxPauseSeconds + ...
    configs{4}.DevelopmentSession.Transition.TimeoutBoundaryDeltaSeconds;

configs{5} = nf_test_step0_config(fullfile(outputRoot, names{5}));
configs{5}.DevelopmentSession.TestHooks.FailurePoint = ...
    Modes.DevelopmentFailure.FeedbackUpdate;
configs{5}.DevelopmentSession.TestHooks.SafetyShutdownFcn = ...
    @local_fail_safety_cleanup;

for iScenario = 1:numel(configs)
    [Result, ~, ~, Logger] = nf_run_development_full_chain(configs{iScenario});
    local_check_expected_scenario(Result, Logger, names{iScenario}, ...
        configs{iScenario}, Modes);
    Scenario = local_readback(Result, configs{iScenario}, Modes);
    Scenario.Name = names{iScenario};
    if isempty(Report.Scenarios)
        Report.Scenarios = Scenario;
    else
        Report.Scenarios(end + 1) = Scenario;
    end
end
Report.Pass = true;

end

function RTConfig = local_refinalize_and_rebuild(RTConfig)
root = RTConfig.Paths.ProjectRoot;
RTConfig = nf_finalize_config(RTConfig);
RTConfig.Paths.ProjectRoot = root;
RTConfig.Source.FieldTrip.TestBufferFcn = ...
    nf_make_development_fieldtrip_buffer(RTConfig);
end

function local_check_expected_scenario(Result, Logger, name, RTConfig, Modes)
assert(Logger.Closed && Result.LoggerClosed);
switch name
    case {'representative_success','positive_backlog','zero_backlog'}
        assert(Result.Pass && Result.Completed && ~Result.Partial);
        assert(strcmp(Result.StopReason, Modes.StopReason.Success));
        assert(Result.BaselineQuality.Pass && Result.BaselineReloaded);
        assert(strcmp(Result.BaselineConfigHash, ...
            Result.TrialBaselineConfigHash));
        assert(Result.FeedbackAudit.NCompletedFlips == ...
            Result.FeedbackAudit.NFlipRequests);
    case 'transition_timeout'
        assert(~Result.Pass && ~Result.Completed && Result.Partial);
        assert(strcmp(Result.StopReason, Modes.StopReason.TransitionTimeout));
        assert(isempty(fieldnames(Result.TrialResult)));
        assert(isempty(fieldnames(Result.FeedbackAudit)));
    case 'injected_failure'
        expectedID = ['neurofeedback:developmentInjected:' ...
            Modes.DevelopmentFailure.FeedbackUpdate];
        assert(~Result.Pass && Result.Partial);
        assert(strcmp(Result.ErrorIdentifier, expectedID));
        assert(any(contains(Result.CleanupMessages, ...
            'Injected Step 0 safety cleanup failure.')));
end

if strcmp(name, 'zero_backlog')
    assert(Result.TransitionResult.RangeKnown && ...
        Result.TransitionResult.NoSamplesSkipped && ...
        Result.TransitionResult.SkippedSampleCount == 0);
elseif strcmp(name, 'positive_backlog')
    assert(Result.TransitionResult.Pass && ...
        Result.TransitionResult.SkippedSampleCount == ...
        RTConfig.DevelopmentSession.Transition.TestAdvanceSamples);
    assert(~Result.TransitionResult.WaitResult.TimedOut);
end
end

function Scenario = local_readback(Result, RTConfig, Modes)
if Result.Pass
    matPath = Result.SummaryPath;
    csvPath = Result.SummaryCsvPath;
else
    matPath = Result.PartialReportPath;
    csvPath = Result.PartialReportCsvPath;
end
htmlPath = Result.TimelinePath;
assert(exist(matPath, 'file') == 2 && exist(csvPath, 'file') == 2);
assert(exist(htmlPath, 'file') == 2);

saved = load(matPath, 'SessionResult', 'RTConfig');
savedResult = saved.SessionResult;
T = readtable(csvPath, 'TextType', 'string');
html = fileread(htmlPath);

assert(strcmp(savedResult.RunID, Result.RunID));
assert(strcmp(savedResult.SessionOutputDir, Result.SessionOutputDir));
assert(isequal(savedResult.Pass, Result.Pass));
assert(isequal(savedResult.Completed, Result.Completed));
assert(isequal(savedResult.Partial, Result.Partial));
assert(strcmp(savedResult.CurrentPhase, Result.CurrentPhase));
assert(strcmp(savedResult.StopReason, Result.StopReason));
assert(strcmp(local_table_text(T.RunID), Result.RunID));
assert(strcmp(local_table_text(T.SessionOutputDir), Result.SessionOutputDir));
assert(T.Pass(1) == Result.Pass && T.Completed(1) == Result.Completed);
assert(T.Partial(1) == Result.Partial);
assert(strcmp(local_table_text(T.StopReason), Result.StopReason));
assert(strcmp(local_table_text(T.OverallStatus), Result.OverallStatus));
assert(contains(html, Result.RunID) && contains(html, Result.OverallStatus));
if ~isempty(Result.CurrentPhase)
    assert(contains(html, Result.CurrentPhase));
end
if ~isempty(Result.StopReason)
    assert(contains(html, Result.StopReason));
end

assert(T.SourceReady(1) == Result.SourceReady);
assert(strcmp(local_table_text(T.SpatialHash), ...
    local_nested_text(Result, {'SpatialSummary','Hash'}, '')));
assert(contains(html, Modes.TimelineEvent.SourceReady));
assert(contains(html, Modes.TimelineEvent.SpatialReady));

if Result.BaselineReloaded
    assert(exist(Result.BaselinePath, 'file') == 2);
    assert(startsWith(Result.BaselinePath, Result.SessionOutputDir));
    baselineFile = load(Result.BaselinePath, 'Baseline');
    assert(strcmp(baselineFile.Baseline.ConfigHash, ...
        Result.BaselineConfigHash));
    assert(strcmp(local_table_text(T.BaselineConfigHash), ...
        Result.BaselineConfigHash));
    if ~isempty(fieldnames(Result.TrialResult))
        assert(strcmp(Result.BaselineConfigHash, ...
            Result.TrialBaselineConfigHash));
    end
    assert(contains(html, Result.BaselinePath));
    assert(contains(html, Modes.TimelineEvent.BaselineReloaded));
end

if ~isempty(fieldnames(Result.TransitionResult))
    local_assert_same_number(T.SkippedFirstSample(1), ...
        Result.TransitionResult.SkippedFirstSample);
    local_assert_same_number(T.SkippedLastSample(1), ...
        Result.TransitionResult.SkippedLastSample);
    local_assert_same_number(T.SkippedSampleCount(1), ...
        Result.TransitionResult.SkippedSampleCount);
end

if ~isempty(fieldnames(Result.TrialResult))
    local_assert_same_number(T.FirstTrialSample(1), ...
        Result.TrialResult.FirstTrialSample);
    local_assert_same_number(T.LastTrialSample(1), ...
        Result.TrialResult.LastTrialSample);
    local_assert_same_number(T.FirstValidMeasureWindowEndSample(1), ...
        Result.TrialResult.FirstValidMeasureWindowEndSample);
    local_assert_same_number(T.FirstFeedbackUpdateWindowEndSample(1), ...
        Result.TrialResult.FirstFeedbackUpdateWindowEndSample);
    assert(strcmp(Result.TrialBaselineConfigHash, ...
        Result.TrialResult.BaselineConfigHash));
    assert(contains(html, Modes.TimelineEvent.TrialFirstValidMeasure));
end

if ~isempty(fieldnames(Result.FeedbackAudit))
    audit = Result.FeedbackAudit;
    assert(T.NFlipRequests(1) == audit.NFlipRequests);
    assert(T.NCompletedFlips(1) == audit.NCompletedFlips);
    assert(T.NMissedFlips(1) == audit.NMissedFlips);
    nTimelineFlips = numel(strfind(html, ...
        ['>' Modes.TimelineEvent.FeedbackFlip '<'])); %#ok<STREMP>
    assert(nTimelineFlips == audit.NFlipRequests);
    if audit.NFlipRequests > 0
        rawMissed = [audit.FlipAudit.Missed];
        assert(isequal(local_parse_numeric_vector( ...
            local_table_text(T.FlipMissedEstimates)), rawMissed));
        assert(audit.NMissedFlips == nnz(rawMissed > 0));
        assert(audit.NMissedFlips == nnz([audit.FlipAudit.DeadlineMissed]));
        assert(contains(html, 'missed deadline estimate'));
    else
        assert(isempty(local_table_text(T.FlipMissedEstimates)));
    end
end

assert(T.LoggerClosed(1) == Result.LoggerClosed);
assert(T.CleanupMessageCount(1) == numel(Result.CleanupMessages));
if ~isempty(Result.CleanupMessages)
    assert(contains(html, Modes.TimelineEvent.CleanupError));
end

tempFiles = dir(fullfile(Result.SessionOutputDir, '**', ...
    ['*' RTConfig.DevelopmentSession.Output.AtomicTempSuffix]));
assert(isempty(tempFiles));

Scenario = struct('Name', '', 'RunID', Result.RunID, ...
    'SessionOutputDir', Result.SessionOutputDir, 'MatPath', matPath, ...
    'CsvPath', csvPath, 'TimelinePath', htmlPath, 'Pass', Result.Pass, ...
    'OverallStatus', Result.OverallStatus, 'StopReason', Result.StopReason);
end

function textValue = local_table_text(value)
if iscell(value)
    value = value{1};
elseif isstring(value) || iscategorical(value)
    value = value(1);
end
if isempty(value) || (isnumeric(value) && isscalar(value) && isnan(value)) || ...
        ((isstring(value) || iscategorical(value)) && ismissing(value))
    textValue = '';
elseif isnumeric(value) && isscalar(value)
    textValue = sprintf('%.17g', value);
else
    textValue = char(value);
end
end

function values = local_parse_numeric_vector(textValue)
if isempty(textValue)
    values = [];
else
    parts = strsplit(textValue, ';');
    values = cellfun(@str2double, parts);
end
end

function value = local_nested_text(S, path, defaultValue)
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

function local_assert_same_number(actual, expected)
assert(isequaln(actual, expected));
end

function local_fail_safety_cleanup(varargin) %#ok<INUSD>
error('neurofeedback:developmentInjected:safety_cleanup', ...
    'Injected Step 0 safety cleanup failure.');
end

function local_remove_tree(pathValue)
if exist(pathValue, 'dir') == 7
    rmdir(pathValue, 's');
end
end
