function [RTConfig, tempRoot] = nf_test_live_self_test_config()
% NF_TEST_LIVE_SELF_TEST_CONFIG Build a hardware-free Step 3D config.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Session.Mode = Modes.Session.LiveSelfTest;
RTConfig.Source.FieldTrip.TestBufferFcn = local_buffer_function();
RTConfig.Source.FieldTrip.AfterManualStartBacklogPolicy = Modes.BufferBacklog.DiscardAccumulated;
RTConfig.Protocol.RequireManualStart = true;
RTConfig.Protocol.AllowAutoStartForTestHook = true;

RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.FieldTrip.RequireCTFRes4 = false;

RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Spatial.Fallback.Type = 'single_channel';
RTConfig.Spatial.Fallback.ChannelIndex = 1;
RTConfig.Spatial.Fallback.ChannelName = '';

RTConfig.Baseline.MinValidWindows = 5;
RTConfig.LiveResting.DurationSeconds = 10;
RTConfig.LiveResting.MinValidMeasures = 5;
RTConfig.LiveResting.MaxTimeouts = 3;

RTConfig.LiveTrial.StopRule = Modes.TrialStop.ManualOrSuccess;
RTConfig.Protocol.Trial.StopRule = Modes.TrialStop.ManualOrSuccess;
RTConfig.Protocol.Trial.Success.Enabled = true;
RTConfig.Protocol.Trial.Success.SourceField = 'ZSmoothed';
RTConfig.Protocol.Trial.Success.Threshold = 0.1;
RTConfig.Protocol.Trial.Success.RequiredConsecutiveValidUpdates = 2;
RTConfig.LiveTrial.MaxTimeouts = 3;

RTConfig.Feedback.Mode = Modes.Feedback.DebugValue;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.None;
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
RTConfig.Feedback.AllowDebugPlotFallback = true;
RTConfig.Feedback.UpdateEveryNValidMeasures = 1;

tempRoot = tempname();
mkdir(tempRoot);
RTConfig.Paths.ProjectRoot = tempRoot;
end

function fcn = local_buffer_function()
% Return a deterministic FieldTrip-buffer-compatible test hook.
state = struct();
state.HeaderCalls = 0;
state.Fs = 2400;
state.NChannels = 3;
state.InitialSamples = 1000;
state.MaxSamples = 250000;
state.ChannelNames = {'MEG001','MEG002','MEG003'};

fcn = @local_call;

    function out = local_call(command, arg, varargin) %#ok<INUSD>
        switch char(command)
            case 'get_hdr'
                state.HeaderCalls = state.HeaderCalls + 1;
                out = local_header(state, state.InitialSamples + 480 * state.HeaderCalls);

            case 'wait_dat'
                requestedStop = arg(1);
                out = local_header(state, max(requestedStop, state.InitialSamples));

            case 'get_dat'
                sampleRange = arg(1):arg(2);
                out = struct();
                out.buf = local_data(state, sampleRange);

            otherwise
                error('Unsupported test buffer command: %s', command);
        end
    end
end

function hdr = local_header(state, nsamples)
% Build a minimal FieldTrip header.
hdr = struct();
hdr.fsample = state.Fs;
hdr.nsamples = min(state.MaxSamples, round(nsamples));
hdr.nchans = state.NChannels;
hdr.channel_names = state.ChannelNames;
end

function X = local_data(state, sampleRange)
% Return target-band data with higher trial-period amplitude.
t = double(sampleRange(:)') ./ state.Fs;
trialGain = 1 + 2 .* double(sampleRange >= 25000);
slowMod = 1 + 0.15 .* sin(2 .* pi .* 0.2 .* t);
target = trialGain .* slowMod .* sin(2 .* pi .* 6 .* t);
X = zeros(state.NChannels, numel(sampleRange));
X(1, :) = target;
X(2, :) = 0.05 .* sin(2 .* pi .* 30 .* t);
X(3, :) = 0.02 .* cos(2 .* pi .* 1 .* t);
end
