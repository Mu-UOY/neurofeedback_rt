function test_step0_config_policies()
% TEST_STEP0_CONFIG_POLICIES Validate final Step 0 policy centralization.

local_check_defaults();
local_check_invalid_boundaries();
local_check_strict_headless_contract();
local_check_incomplete_readiness_dispatch();
local_check_geometry_consumption();
local_check_latency_percentile();
end

function local_check_defaults()
RTConfig = nf_live_config();
circle = RTConfig.Feedback.Circle;
assert(circle.DebugAxesMarginScale == 1.1);
assert(circle.FixationMinHalfWidthPx == 3);
assert(circle.FixationHalfWidthFraction == 0.025);
assert(circle.OuterCircleLineWidthPx == 2);
assert(circle.FixationLineWidthPx == 1);
assert(RTConfig.Feedback.LatencySummary.Percentile == 95);
assert(isempty(RTConfig.DevelopmentSession.TestHooks.SafetyShutdownFcn));
assert(isempty(RTConfig.DevelopmentSession.TestHooks.PauseFcn));
end

function local_check_invalid_boundaries()
cases = { ...
    {'Feedback','Circle','DebugAxesMarginScale'}, 1; ...
    {'Feedback','Circle','DebugAxesMarginScale'}, Inf; ...
    {'Feedback','Circle','FixationMinHalfWidthPx'}, -1; ...
    {'Feedback','Circle','FixationHalfWidthFraction'}, 0; ...
    {'Feedback','Circle','FixationHalfWidthFraction'}, 0.5 + eps(0.5); ...
    {'Feedback','Circle','OuterCircleLineWidthPx'}, 0; ...
    {'Feedback','Circle','FixationLineWidthPx'}, 0; ...
    {'Feedback','LatencySummary','Percentile'}, 0; ...
    {'Feedback','LatencySummary','Percentile'}, 100; ...
    {'DevelopmentSession','Feedback','FlipWhen'}, Inf; ...
    {'DevelopmentSession','TestHooks','SafetyShutdownFcn'}, 1; ...
    {'DevelopmentSession','TestHooks','PauseFcn'}, 1};
for iCase = 1:size(cases, 1)
    RTConfig = nf_test_step0_config(tempname);
    RTConfig = local_set_nested(RTConfig, cases{iCase, 1}, cases{iCase, 2});
    local_expect_invalid(RTConfig);
end
end

function local_check_strict_headless_contract()
Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
RTConfig = nf_finalize_config(RTConfig);
assert(nf_is_strict_step0_headless_contract(RTConfig));
assert(RTConfig.DevelopmentSession.Enabled);
assert(strcmp(RTConfig.DevelopmentSession.DisplayMode, ...
    Modes.DevelopmentDisplay.HeadlessPsychtoolboxTest));
assert(RTConfig.DevelopmentSession.TestHooks.Enabled);
assert(isa(RTConfig.Source.FieldTrip.TestBufferFcn, 'function_handle'));
assert(strcmp(RTConfig.Source.FieldTrip.StreamRole, Modes.StreamRole.TestHook));
assert(isa(RTConfig.DevelopmentSession.TestHooks.ScreenFcn, 'function_handle'));
assert(isa(RTConfig.DevelopmentSession.TestHooks.TimeFcn, 'function_handle'));
assert(~RTConfig.Session.ProductionEquivalent);

for iCase = 1:8
    incomplete = nf_test_step0_config(tempname);
    switch iCase
        case 1
            incomplete.DevelopmentSession.Enabled = false;
        case 2
            incomplete.DevelopmentSession.DisplayMode = ...
                Modes.DevelopmentDisplay.RealPsychtoolbox;
        case 3
            incomplete.DevelopmentSession.TestHooks.Enabled = false;
        case 4
            incomplete.DevelopmentSession.TestHooks.ScreenFcn = [];
        case 5
            incomplete.DevelopmentSession.TestHooks.TimeFcn = [];
        case 6
            incomplete.Source.FieldTrip.StreamRole = Modes.StreamRole.Unknown;
        case 7
            incomplete.Session.ProductionEquivalent = true;
        case 8
            incomplete.Source.FieldTrip.TestBufferFcn = 1;
    end
    assert(~nf_is_strict_step0_headless_contract(incomplete));
    local_expect_invalid(incomplete);
end

malformedInputs = {[], 1, struct(), struct('DevelopmentSession', 1), ...
    struct('DevelopmentSession', struct('Enabled', true))};
for iInput = 1:numel(malformedInputs)
    assert(~nf_is_strict_step0_headless_contract(malformedInputs{iInput}));
end

missingBuffer = nf_test_step0_config(tempname);
missingBuffer.Source.FieldTrip.TestBufferFcn = [];
missingBuffer.Source.FieldTrip.Host = 'test-host';
missingBuffer.Source.FieldTrip.Port = 1;
local_expect_invalid(missingBuffer);

realConfig = nf_development_session_config();
realConfig.DevelopmentSession.TestHooks.Enabled = true;
local_expect_invalid(realConfig);

disabled = nf_test_step0_config(tempname);
disabled.DevelopmentSession.Enabled = false;
disabled.DevelopmentSession.DisplayMode = '';
disabled.Session.Mode = Modes.Session.LiveSelfTest;
disabled.Session.DevelopmentOnly = false;
disabled.DevelopmentSession.TestHooks.Enabled = false;
disabled.DevelopmentSession.TestHooks.FailurePoint = Modes.DevelopmentFailure.None;
disabled.DevelopmentSession.TestHooks.ScreenFcn = [];
disabled.DevelopmentSession.TestHooks.TimeFcn = [];
disabled.DevelopmentSession.TestHooks.SafetyShutdownFcn = @local_noop;
local_expect_invalid(disabled);
disabled.DevelopmentSession.TestHooks.SafetyShutdownFcn = [];
disabled.DevelopmentSession.TestHooks.PauseFcn = @local_noop;
local_expect_invalid(disabled);
end

function local_check_incomplete_readiness_dispatch()
for iCase = 1:8
    local_probe_incomplete_readiness(iCase);
end
end

function local_probe_incomplete_readiness(iCase)
Modes = nf_modes();
RTConfig = nf_test_step0_config(tempname);
baseBuffer = RTConfig.Source.FieldTrip.TestBufferFcn;
rawHeader = baseBuffer('get_hdr', [], '', []);
headerCalls = 0;
advanceCalls = 0;
RTConfig.Source.FieldTrip.TestBufferFcn = @local_probe_buffer;
switch iCase
    case 1
        RTConfig.DevelopmentSession.Enabled = false;
    case 2
        RTConfig.DevelopmentSession.DisplayMode = Modes.DevelopmentDisplay.RealPsychtoolbox;
    case 3
        RTConfig.DevelopmentSession.TestHooks.Enabled = false;
    case 4
        RTConfig.DevelopmentSession.TestHooks.ScreenFcn = [];
    case 5
        RTConfig.DevelopmentSession.TestHooks.TimeFcn = [];
    case 6
        RTConfig.Source.FieldTrip.StreamRole = Modes.StreamRole.Unknown;
    case 7
        RTConfig.Session.ProductionEquivalent = true;
    case 8
        RTConfig.Source.FieldTrip.TestBufferFcn = 1;
end
Header0 = struct('NSamples', rawHeader.nsamples, 'Fs', rawHeader.fsample);
if iCase == 8
    didError = false;
    try
        nf_live_detect_acq_block_size(RTConfig, Header0);
    catch
        didError = true;
    end
    assert(didError);
else
    BlockInfo = nf_live_detect_acq_block_size(RTConfig, Header0);
    assert(BlockInfo.Pass && BlockInfo.SampleCountAdvanced);
end
assert(advanceCalls == 0);

    function output = local_probe_buffer(command, arg, host, port)
        if strcmp(char(command), Modes.TestBufferCommand.Advance)
            advanceCalls = advanceCalls + 1;
            output = baseBuffer(command, arg, host, port);
        elseif strcmp(char(command), 'get_hdr')
            headerCalls = headerCalls + 1;
            output = baseBuffer(command, arg, host, port);
            output.nsamples = rawHeader.nsamples + headerCalls;
        else
            output = baseBuffer(command, arg, host, port);
        end
    end
end

function local_check_geometry_consumption()
Modes = nf_modes();
debugConfig = nf_live_config();
debugConfig.Feedback.Mode = Modes.Feedback.DebugPlot;
debugConfig.Feedback.Backend = Modes.FeedbackBackend.DebugPlot;
debugConfig.Feedback.Circle.DebugAxesMarginScale = ...
    2 .* debugConfig.Feedback.Circle.DebugAxesMarginScale;
Feedback = nf_feedback_init(debugConfig);
cleanup = onCleanup(@() nf_feedback_close(Feedback)); %#ok<NASGU>
expectedMargin = debugConfig.Feedback.Circle.DebugAxesMarginScale .* ...
    debugConfig.Feedback.Circle.MaxRadiusPx;
assert(all(abs(xlim(Feedback.AxesHandle) - [-expectedMargin expectedMargin]) < ...
    eps(expectedMargin)));

Measure = local_measure(debugConfig);
[Feedback, ~] = nf_feedback_update(Feedback, Measure, debugConfig);
assert(all(abs(xlim(Feedback.AxesHandle) - [-expectedMargin expectedMargin]) < ...
    eps(expectedMargin)));
Feedback = nf_feedback_close(Feedback);
clear cleanup

headlessConfig = nf_test_step0_config(tempname);
circle = headlessConfig.Feedback.Circle;
headlessConfig.Feedback.Circle.OuterCircleLineWidthPx = ...
    circle.OuterCircleLineWidthPx + circle.FixationLineWidthPx;
headlessConfig.Feedback.Circle.FixationLineWidthPx = ...
    2 .* circle.FixationLineWidthPx;
headlessConfig.Feedback.Circle.FixationMinHalfWidthPx = ...
    circle.FixationMinHalfWidthPx + circle.FixationLineWidthPx;
Feedback = nf_feedback_init(headlessConfig);
Measure = local_measure(headlessConfig);
[Feedback, ~] = nf_feedback_update(Feedback, Measure, headlessConfig);
fakePTB = headlessConfig.DevelopmentSession.TestHooks.FakePsychtoolbox;
expectedHalfWidth = max(headlessConfig.Feedback.Circle.FixationMinHalfWidthPx, ...
    headlessConfig.Feedback.Circle.FixationHalfWidthFraction .* ...
    headlessConfig.Feedback.Circle.MaxRadiusPx);
assert(fakePTB.LastFrameOvalLineWidthPx == ...
    headlessConfig.Feedback.Circle.OuterCircleLineWidthPx);
assert(all(fakePTB.DrawLineWidthsPx == ...
    headlessConfig.Feedback.Circle.FixationLineWidthPx));
assert(all(fakePTB.DrawLineHalfWidthsPx == expectedHalfWidth));
Feedback = nf_feedback_close(Feedback);
end

function local_check_latency_percentile()
RTConfig = nf_test_step0_config(tempname);
RTConfig.Feedback.LatencySummary.Percentile = ...
    100 - RTConfig.Feedback.LatencySummary.Percentile;
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = ...
    RTConfig.Feedback.UpdateEveryNValidMeasures + 1;
[Result, ~] = nf_run_development_full_chain(RTConfig);
values = sort(Result.TrialResult.FeedbackLatencyMsValues(:));
assert(Result.Pass && numel(values) > 1);
assert(Result.TrialResult.FeedbackLatencyPercentile == ...
    RTConfig.Feedback.LatencySummary.Percentile);
assert(Result.FeedbackAudit.LatencyPercentile == ...
    RTConfig.Feedback.LatencySummary.Percentile);
expected = local_percentile(values, RTConfig.Feedback.LatencySummary.Percentile);
expectedP95 = local_percentile(values, 95);
assert(Result.TrialResult.FeedbackLatencyConfiguredPercentileMs == expected);
assert(Result.FeedbackAudit.LatencyConfiguredPercentileMs == expected);
assert(Result.TrialResult.FeedbackLatencyMsP95 == expectedP95);
assert(Result.FeedbackAudit.LatencyP95Ms == expectedP95);
end

function Measure = local_measure(RTConfig)
Measure = nf_measure_empty();
Measure.Time = 1;
Measure.WindowStartSample = 1;
Measure.WindowEndSample = RTConfig.PowerWindowSamples;
Measure.ValidMeasureIndex = 1;
Measure.FeedbackTargetRadiusPx = RTConfig.Feedback.Circle.MinRadiusPx;
Measure.FeedbackDisplayRadiusPx = RTConfig.Feedback.Circle.MinRadiusPx;
Measure.FeedbackOuterRadiusPx = RTConfig.Feedback.Circle.MaxRadiusPx;
Measure.FeedbackDisplayType = nf_modes().FeedbackDisplay.Circle;
end

function local_expect_invalid(RTConfig)
didError = false;
try
    nf_finalize_config(RTConfig);
catch
    didError = true;
end
assert(didError);
end

function S = local_set_nested(S, path, value)
if numel(path) == 1
    S.(path{1}) = value;
else
    fieldName = path{1};
    S.(fieldName) = local_set_nested(S.(fieldName), path(2:end), value);
end
end

function value = local_percentile(values, pct)
position = 1 + (pct ./ 100) .* (numel(values) - 1);
lowerIndex = floor(position);
upperIndex = ceil(position);
if lowerIndex == upperIndex
    value = values(lowerIndex);
else
    value = values(lowerIndex) .* (upperIndex - position) + ...
        values(upperIndex) .* (position - lowerIndex);
end
end

function local_noop(varargin) %#ok<INUSD>
end
