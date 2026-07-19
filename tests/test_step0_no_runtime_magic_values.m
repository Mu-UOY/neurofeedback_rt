function test_step0_no_runtime_magic_values()
% TEST_STEP0_NO_RUNTIME_MAGIC_VALUES Audit Step 0 runtime centralization.

root = nf_project_root();
relativeFiles = { ...
    fullfile('analysis','nf_save_development_session_report.m'), ...
    fullfile('feedback','nf_feedback_init.m'), ...
    fullfile('feedback','nf_feedback_update.m'), ...
    fullfile('main','nf_development_maybe_inject_failure.m'), ...
    fullfile('main','nf_development_timeline_append.m'), ...
    fullfile('main','nf_development_timeline_init.m'), ...
    fullfile('main','nf_run_development_full_chain.m'), ...
    fullfile('main','nf_run_development_transition.m'), ...
    fullfile('main','nf_run_live_resting.m'), ...
    fullfile('main','nf_run_live_trial.m'), ...
    fullfile('main','nf_wait_for_manual_start.m'), ...
    fullfile('source','nf_live_detect_acq_block_size.m'), ...
    fullfile('source','nf_make_development_fieldtrip_buffer.m'), ...
    fullfile('source','nf_source_resync_after_pause.m'), ...
    fullfile('spatial','nf_prepare_live_combined_matrix.m')};
texts = cell(size(relativeFiles));
for iFile = 1:numel(relativeFiles)
    filePath = fullfile(root, relativeFiles{iFile});
    assert(exist(filePath, 'file') == 2, 'Missing audited Step 0 runtime file.');
    texts{iFile} = fileread(filePath);
    assert(isempty(regexp(texts{iFile}, ...
        'pause\s*\(\s*[-+]?\d', 'once')), ...
        'Runtime pause duration must come from RTConfig.');
end

%% ===== REJECT CONFIG-DERIVED ROOM/WORKLOAD LITERALS =====
% Structural 0/1/-1, MATLAB/API dimensions, FieldTrip/Psychtoolbox commands,
% unit conversions, intrinsic constants, and report/HTML formatting are
% intentionally outside this numeric audit.
RTConfig = nf_test_step0_config(tempname, true);
policyValues = [RTConfig.Fs, RTConfig.ChunkSamples, ...
    RTConfig.PowerWindowSamples, ...
    RTConfig.DevelopmentSession.Input.PrimaryMEGChannelCount, ...
    RTConfig.DevelopmentSession.Input.ReferenceMEGChannelCount, ...
    RTConfig.DevelopmentSession.Input.TotalChannelCount, ...
    RTConfig.DevelopmentSession.Matrix.OutputRowUpperBound, ...
    RTConfig.DevelopmentSession.Transition.MaxPauseSeconds];
policyValues = unique(policyValues(policyValues > 1));
for iValue = 1:numel(policyValues)
    token = regexptranslate('escape', sprintf('%.15g', policyValues(iValue)));
    expression = ['(?<![A-Za-z0-9_.])' token '(?![A-Za-z0-9_.])'];
    for iFile = 1:numel(texts)
        assert(isempty(regexp(texts{iFile}, expression, 'once')), ...
            'Step 0 room/workload value is duplicated outside config.');
    end
end

%% ===== REJECT QUOTED CENTRAL MODE TOKENS =====
Modes = nf_modes();
centralTokens = local_flatten_values({Modes.Session.DevelopmentFullChain, ...
    Modes.DevelopmentDisplay, Modes.DevelopmentStatus, ...
    Modes.DevelopmentFailure.RestingProcessing, ...
    Modes.DevelopmentFailure.Transition, ...
    Modes.DevelopmentFailure.TrialProcessing, ...
    Modes.DevelopmentFailure.FeedbackUpdate, ...
    Modes.DevelopmentFailure.LoggerAppend, ...
    Modes.DevelopmentFailure.LoggerClose, ...
    Modes.ReadinessStatus, Modes.TimelineEvent, Modes.StopReason.TransitionTimeout, ...
    Modes.Spatial.FallbackType.RepresentativeDense, ...
    Modes.FeedbackBackend.Psychtoolbox});
for iToken = 1:numel(centralTokens)
    quoted = ['''' centralTokens{iToken} ''''];
    for iFile = 1:numel(texts)
        assert(~contains(texts{iFile}, quoted), ...
            'Step 0 mode/event/status/failure token is duplicated outside nf_modes.');
    end
end

%% ===== STATIC OWNERSHIP REJECTIONS =====
orchestrator = fileread(fullfile(root, 'main', 'nf_run_development_full_chain.m'));
assert(numel(regexp(orchestrator, 'nf_source_init\s*\(', 'match')) == 1);
assert(numel(regexp(orchestrator, 'nf_prepare_live_combined_matrix\s*\(', 'match')) == 1);
assert(numel(regexp(orchestrator, 'nf_logger_init\s*\(', 'match')) == 1);
assert(~contains(orchestrator, 'nf_rt_process_chunk'));
assert(~contains(orchestrator, 'DebugPlot') && ~contains(orchestrator, 'debug_plot'));
assert(isempty(regexp(orchestrator, 'ProductionEquivalent\s*[,=]\s*true', 'once')));

producer = fileread(fullfile(root, 'source', 'nf_make_development_fieldtrip_buffer.m'));
assert(contains(producer, 'nf_ctf275_primary_channel_names'));
assert(isempty(regexp(producer, 'sprintf\s*\(\s*''MEG', 'once')));

resting = fileread(fullfile(root, 'main', 'nf_run_live_resting.m'));
trial = fileread(fullfile(root, 'main', 'nf_run_live_trial.m'));
assert(numel(regexp(resting, 'nf_rt_process_chunk\s*\(', 'match')) == 1);
assert(numel(regexp(trial, 'nf_rt_process_chunk\s*\(', 'match')) == 1);

feedbackInit = fileread(fullfile(root, 'feedback', 'nf_feedback_init.m'));
feedbackUpdate = fileread(fullfile(root, 'feedback', 'nf_feedback_update.m'));
assert(contains(feedbackInit, 'circle.DebugAxesMarginScale'));
geometryFields = {'DebugAxesMarginScale','FixationMinHalfWidthPx', ...
    'FixationHalfWidthFraction','OuterCircleLineWidthPx','FixationLineWidthPx'};
for iField = 1:numel(geometryFields)
    assert(contains(feedbackUpdate, ['circle.' geometryFields{iField}]));
end
assert(isempty(regexp(feedbackInit, ...
    'margin\s*=\s*1\.1\s*\.\*\s*maxRadius', 'once')));
assert(isempty(regexp(feedbackUpdate, ...
    'margin\s*=\s*1\.1\s*\.\*\s*maxRadius', 'once')));
assert(isempty(regexp(feedbackUpdate, ...
    'max\s*\(\s*3\s*,\s*0\.025\s*\.\*', 'once')));
assert(isempty(regexp(feedbackUpdate, ...
    '''LineWidth''\s*,\s*[12](?![0-9.])', 'once')));
assert(isempty(regexp(feedbackUpdate, ...
    'FrameOval[\s\S]{0,200},\s*2\s*\)', 'once')));
assert(isempty(regexp(feedbackUpdate, ...
    'DrawLine[\s\S]{0,250},\s*1\s*\)', 'once')));

assert(contains(trial, 'RTConfig.Feedback.LatencySummary.Percentile'));
assert(contains(trial, 'FeedbackLatencyConfiguredPercentileMs'));
assert(contains(trial, ...
    'Result.FeedbackLatencyMsP95 = local_true_p95(values)'));
assert(contains(trial, ...
    'Audit.LatencyP95Ms = local_true_p95(sortedValues)'));
assert(isempty(regexp(trial, ...
    'FeedbackLatencyMsP95\s*=\s*local_percentile[\s\S]{0,120}LatencySummary', ...
    'once')));

helperName = 'nf_is_strict_step0_headless_contract';
allMatlab = dir(fullfile(root, '**', '*.m'));
nImplementations = 0;
nLegacyImplementations = 0;
for iFile = 1:numel(allMatlab)
    fileText = fileread(fullfile(allMatlab(iFile).folder, allMatlab(iFile).name));
    nImplementations = nImplementations + numel(regexp(fileText, ...
        ['function\s+tf\s*=\s*' helperName '\s*\('], 'match'));
    nLegacyImplementations = nLegacyImplementations + numel(regexp(fileText, ...
        'function\s+tf\s*=\s*local_is_strict_step0_headless_contract\s*\(', ...
        'match'));
end
assert(nImplementations == 1);
assert(nLegacyImplementations == 0);
strictConsumers = { ...
    fullfile('config','private','nf_check_live_config.m'), ...
    fullfile('feedback','nf_feedback_init.m'), ...
    fullfile('main','nf_development_maybe_inject_failure.m'), ...
    fullfile('main','nf_run_development_transition.m'), ...
    fullfile('main','nf_run_live_resting.m'), ...
    fullfile('main','nf_run_live_trial.m'), ...
    fullfile('main','nf_wait_for_manual_start.m'), ...
    fullfile('source','nf_live_detect_acq_block_size.m'), ...
    fullfile('source','nf_make_development_fieldtrip_buffer.m')};
for iFile = 1:numel(strictConsumers)
    assert(contains(fileread(fullfile(root, strictConsumers{iFile})), ...
        [helperName '(']));
end

%% ===== DYNAMIC STEP 0 PATH-SHADOW PREVENTION =====
surfacePatterns = {'*step0*.m','NFStep0*.m'};
step0Surfaces = {};
for iPattern = 1:numel(surfacePatterns)
    matches = dir(fullfile(root, 'tests', surfacePatterns{iPattern}));
    paths = arrayfun(@(item) fullfile(item.folder, item.name), ...
        matches, 'UniformOutput', false);
    step0Surfaces = [step0Surfaces, reshape(paths, 1, [])]; %#ok<AGROW>
end
step0Surfaces = unique(step0Surfaces, 'stable');
allStep0Text = cell(1, numel(step0Surfaces));
for iFile = 1:numel(step0Surfaces)
    allStep0Text{iFile} = fileread(step0Surfaces{iFile});
    assert(~local_has_path_shadow_code(allStep0Text{iFile}), ...
        'Step 0 tests/helpers must not mutate path or generate function shadows.');
end
assert(~local_has_path_shadow_code(strjoin(allStep0Text, newline)), ...
    'Split Step 0 helpers/tests combine to form path-shadow behavior.');

forbiddenFixtures = { ...
    'addpath(tempdir);', ...
    'addpath tempdir', ...
    'rmpath tempdir', ...
    'rehash', ...
    'clear nf_safety_shutdown', ...
    sprintf('clear(%cnf_safety_shutdown%c);', 39, 39), ...
    ['functionName = ''nf_safety_shutdown''; ' ...
     'clear(functionName);'], ...
    'fid = fopen(fullfile(tempdir, ''nf_safety_shutdown.m''), ''w'');', ...
    ['name = ''nf_safety_shutdown''; fid = fopen(' ...
     'fullfile(tempdir, [name ''.m'']), ''w''); fwrite(fid, 1);'], ...
    ['copyfile(''source.m'', fullfile(tempdir, ' ...
     '''nf_safety_shutdown.m''));']};
for iFixture = 1:numel(forbiddenFixtures)
    assert(local_has_path_shadow_code(forbiddenFixtures{iFixture}), ...
        'Path-shadow scanner missed fixture %d.', iFixture);
end
allowedFixtures = { ...
    '% addpath(tempdir)', ...
    'textValue = ''addpath(tempdir)'';', ...
    'clear cleanup', ...
    'fprintf(''Do not generate a replacement MATLAB function.'');'};
for iFixture = 1:numel(allowedFixtures)
    assert(~local_has_path_shadow_code(allowedFixtures{iFixture}), ...
        'Path-shadow scanner rejected allowed fixture %d.', iFixture);
end

manualStart = fileread(fullfile(root, 'main', 'nf_wait_for_manual_start.m'));
assert(~contains(manualStart, 'RTConfig.Session.Mode'));
reportText = fileread(fullfile(root, 'analysis', ...
    'nf_save_development_session_report.m'));
assert(isempty(regexp(reportText, '''[^'']+\.(mat|csv|html)''', 'once')));

% Static checks enforce literals, ownership, strict-predicate references, and
% path-shadow rejection. Config-policy tests enforce numeric boundaries and
% runtime geometry/percentile consumption; fresh-trial and failure tests
% enforce transition exclusion, incremental events, and cleanup precedence.
end

function values = local_flatten_values(value)
values = {};
if iscell(value)
    for iValue = 1:numel(value)
        values = [values, local_flatten_values(value{iValue})]; %#ok<AGROW>
    end
elseif isstruct(value)
    fields = fieldnames(value);
    for iField = 1:numel(fields)
        values = [values, local_flatten_values(value.(fields{iField}))]; %#ok<AGROW>
    end
elseif ischar(value) || (isstring(value) && isscalar(value))
    values = {char(value)};
end
values = unique(values, 'stable');
end

function tf = local_has_path_shadow_code(textValue)
% Detect executable path mutation and generated nf_*.m replacements.
[codeOnly, commentsRemoved] = local_strip_matlab_text(textValue);
tf = false;
pathCalls = {'addpath','rmpath','rehash','restoredefaultpath','pathtool'};
for iCall = 1:numel(pathCalls)
    if ~isempty(regexp(codeOnly, ...
            ['(?<![A-Za-z0-9_])' pathCalls{iCall} '\s*\('], 'once'))
        tf = true;
        return;
    end
end
commandPathPattern = ['(?<![A-Za-z0-9_.])' ...
    '(addpath|rmpath|rehash|restoredefaultpath|pathtool)\>(?!\s*\()'];
if ~isempty(regexp(codeOnly, commandPathPattern, 'once'))
    tf = true;
    return;
end
if ~isempty(regexp(codeOnly, ...
        ['(?<![A-Za-z0-9_])clear\s+' ...
        '(all\>|classes\>|functions\>|nf_[A-Za-z0-9_]+\>)'], 'once'))
    tf = true;
    return;
end
hasClearCall = ~isempty(regexp(codeOnly, ...
    '(?<![A-Za-z0-9_])clear\s*\(', 'once'));
hasQuotedClearTarget = ~isempty(regexp(commentsRemoved, ...
    ['(?<![A-Za-z0-9_])clear\s*\(\s*[''"]\s*' ...
    '(all|classes|functions|nf_[A-Za-z0-9_]+)\s*[''"]'], 'once'));
hasDynamicClearTarget = ~isempty(regexp(codeOnly, ...
    ['(?<![A-Za-z0-9_])clear\s*\(\s*' ...
    '(?=[A-Za-z0-9_]*(function|shadow))' ...
    '[A-Za-z][A-Za-z0-9_]*\s*\)'], 'once'));
if hasClearCall && (hasQuotedClearTarget || hasDynamicClearTarget)
    tf = true;
    return;
end

writerCalls = {'fopen','writelines','writecell','writematrix', ...
    'copyfile','movefile','save','websave','urlwrite','system','unix','dos'};
hasWriter = false;
for iCall = 1:numel(writerCalls)
    hasWriter = hasWriter || ~isempty(regexp(codeOnly, ...
        ['(?<![A-Za-z0-9_])' writerCalls{iCall} '\s*\('], 'once'));
end
hasDirectReplacementName = ~isempty(regexp(commentsRemoved, ...
    '[''"][^''"\r\n]*nf_[A-Za-z0-9_]+\.m[^''"\r\n]*[''"]', 'once'));
hasProductionName = ~isempty(regexp(commentsRemoved, ...
    '[''"]nf_[A-Za-z0-9_]+[''"]', 'once'));
hasMatlabSuffix = ~isempty(regexp(commentsRemoved, ...
    '[''"]\.m[''"]', 'once'));
hasDynamicFunctionName = ~isempty(regexp(codeOnly, ...
    '(?<![A-Za-z0-9_])[A-Za-z][A-Za-z0-9_]*function[A-Za-z0-9_]*\>', 'once'));
tf = hasWriter && (hasDirectReplacementName || ...
    (hasMatlabSuffix && (hasProductionName || hasDynamicFunctionName)));
end

function [codeOnly, commentsRemoved] = local_strip_matlab_text(textValue)
% Strip comments and quoted contents while retaining executable call syntax.
lines = regexp(char(textValue), '\r\n|\n|\r', 'split');
codeLines = cell(size(lines));
commentLines = cell(size(lines));
for iLine = 1:numel(lines)
    [codeLines{iLine}, commentLines{iLine}] = local_strip_line(lines{iLine});
end
codeOnly = strjoin(codeLines, newline);
commentsRemoved = strjoin(commentLines, newline);
end

function [withoutStrings, withoutComments] = local_strip_line(lineText)
withoutStrings = repmat(' ', size(lineText));
withoutComments = repmat(' ', size(lineText));
inSingle = false;
inDouble = false;
iChar = 1;
while iChar <= numel(lineText)
    ch = lineText(iChar);
    if ~inSingle && ~inDouble && ch == '%'
        break;
    end
    withoutComments(iChar) = ch;
    if inSingle
        if ch == '''' && iChar < numel(lineText) && lineText(iChar + 1) == ''''
            withoutComments(iChar + 1) = lineText(iChar + 1);
            iChar = iChar + 2;
            continue;
        elseif ch == ''''
            inSingle = false;
        end
    elseif inDouble
        if ch == '"' && iChar < numel(lineText) && lineText(iChar + 1) == '"'
            withoutComments(iChar + 1) = lineText(iChar + 1);
            iChar = iChar + 2;
            continue;
        elseif ch == '"'
            inDouble = false;
        end
    elseif ch == '"'
        inDouble = true;
    elseif ch == '''' && local_starts_string(lineText, iChar)
        inSingle = true;
    else
        withoutStrings(iChar) = ch;
    end
    iChar = iChar + 1;
end
end

function tf = local_starts_string(lineText, quoteIndex)
% Distinguish a character literal from MATLAB's transpose operator.
prefix = strtrim(lineText(1:max(0, quoteIndex - 1)));
if isempty(prefix)
    tf = true;
    return;
end
tf = any(prefix(end) == ['=' '(' '[' '{' ',' ';' ':']);
end
