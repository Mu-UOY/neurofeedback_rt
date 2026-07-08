function [RTConfig, tempRoot] = nf_test_live_rt_dry_run_config(nChunks)
% NF_TEST_LIVE_RT_DRY_RUN_CONFIG Build a hardware-free Step 3C test config.

if nargin < 1 || isempty(nChunks)
    nChunks = 35;
end

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Session.Mode = Modes.Session.LiveRTDryRun;
RTConfig.Feedback.Mode = Modes.Feedback.None;
RTConfig.LiveRTDryRun.NChunks = nChunks;
RTConfig.LiveRTDryRun.RequireAtLeastOneValidMeasure = true;
RTConfig.LiveRTDryRun.RequireTimingPass = false;
RTConfig.Source.FieldTrip.TestBufferFcn = local_buffer_function();

RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Spatial.Fallback.Type = 'single_channel';
RTConfig.Spatial.Fallback.ChannelIndex = 1;
RTConfig.Spatial.Fallback.ChannelName = '';

RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.FieldTrip.RequireCTFRes4 = false;

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
state.MaxSamples = 50000;
state.ChannelNames = {'MEG001','MEG002','MEG003'};

fcn = @local_call;

    function out = local_call(command, arg, varargin) %#ok<INUSD>
        switch char(command)
            case 'get_hdr'
                state.HeaderCalls = state.HeaderCalls + 1;
                out = local_header(state, state.InitialSamples + 480 * max(0, state.HeaderCalls - 1));

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
% Return deterministic target-band activity on the first channel.
t = double(sampleRange(:)') ./ state.Fs;
target = sin(2 .* pi .* 6 .* t);
X = zeros(state.NChannels, numel(sampleRange));
X(1, :) = target;
X(2, :) = 0.05 .* sin(2 .* pi .* 30 .* t);
X(3, :) = 0.02 .* cos(2 .* pi .* 1 .* t);
end
