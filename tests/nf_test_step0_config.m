function RTConfig = nf_test_step0_config(outputRoot, useRepresentativeWorkload)
% NF_TEST_STEP0_CONFIG Build an isolated fast headless Step 0 config.

if nargin < 1 || isempty(outputRoot)
    outputRoot = tempname;
end
if nargin < 2 || isempty(useRepresentativeWorkload)
    useRepresentativeWorkload = false;
end
if exist(outputRoot, 'dir') == 0
    mkdir(outputRoot);
end
Modes = nf_modes();
RTConfig = nf_development_session_config();
if ~useRepresentativeWorkload
    RTConfig.DevelopmentSession.Matrix.OutputRowUpperBound = max(1, ...
        ceil(sqrt(RTConfig.DevelopmentSession.Input.TotalChannelCount)));
end

windowRect = [0 0 800 600];
fakePTB = NFStep0FakePsychtoolbox(windowRect, RTConfig.ChunkSeconds);
RTConfig.DevelopmentSession.DisplayMode = ...
    Modes.DevelopmentDisplay.HeadlessPsychtoolboxTest;
RTConfig.DevelopmentSession.TestHooks.Enabled = true;
RTConfig.DevelopmentSession.TestHooks.ScreenFcn = @fakePTB.screen;
RTConfig.DevelopmentSession.TestHooks.TimeFcn = @fakePTB.time;
RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox = fakePTB;
RTConfig.Protocol.AllowAutoStartForTestHook = true;
RTConfig.Safety.EnableKeyboardStop = false;
RTConfig.Safety.EnableStopFile = false;
RTConfig.Safety.UseMaxDurationFailsafe = false;
RTConfig.Baseline.MinValidWindows = 3;
RTConfig.Baseline.OutlierMethod = 'none';
RTConfig.LiveResting.MinValidMeasures = RTConfig.Baseline.MinValidWindows;
RTConfig.LiveResting.DurationSeconds = RTConfig.PowerWindowSeconds + ...
    (RTConfig.Baseline.MinValidWindows - 1) .* RTConfig.ChunkSeconds;
RTConfig.Protocol.Trial.Success.Enabled = true;
RTConfig.Protocol.Trial.Success.Threshold = -realmax;
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = 1;
RTConfig.LiveTrial.TestMaxIterations = ...
    RTConfig.PowerWindowSamples ./ RTConfig.ChunkSamples + 2;
RTConfig.Paths.ProjectRoot = outputRoot;
RTConfig.Debug.Verbose = false;
RTConfig = nf_finalize_config(RTConfig);
RTConfig.Paths.ProjectRoot = outputRoot;
RTConfig.Source.FieldTrip.TestBufferFcn = nf_make_development_fieldtrip_buffer(RTConfig);

end
