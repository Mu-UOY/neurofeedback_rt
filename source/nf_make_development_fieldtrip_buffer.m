function bufferFcn = nf_make_development_fieldtrip_buffer(RTConfig)
% NF_MAKE_DEVELOPMENT_FIELDTRIP_BUFFER Create the Step 0 test transport.
%
% USAGE:  bufferFcn = nf_make_development_fieldtrip_buffer(RTConfig)
%
% DESCRIPTION:
%     Returns a stateful FieldTrip TestBufferFcn-compatible closure. The
%     generated signal is deterministic and exists only to exercise the
%     production-shaped transport and processing workload.

Modes = nf_modes();
primaryNames = nf_ctf275_primary_channel_names();
referenceNames = nf_step0_provisional_reference_channel_names(RTConfig);
channelNames = [primaryNames, referenceNames];

availableSamples = RTConfig.DevelopmentSession.Source.InitialAvailableSamples;
capacitySamples = RTConfig.DevelopmentSession.Source.CapacitySamples;
startedTic = tic;
timeFcn = RTConfig.DevelopmentSession.TestHooks.TimeFcn;
pauseFcn = RTConfig.DevelopmentSession.TestHooks.PauseFcn;
useLogicalTime = nf_is_strict_step0_headless_contract(RTConfig);
if useLogicalTime
    logicalStartTime = double(timeFcn());
else
    logicalStartTime = NaN;
end

bufferFcn = @local_buffer;

    function output = local_buffer(command, arg, ~, ~)
        % Match the command-first FieldTrip test-buffer adapter contract.
        local_update_available();
        switch char(command)
            case 'get_hdr'
                output = local_header();

            case 'wait_dat'
                [targetSample, timeoutSeconds] = local_wait_request(arg);
                local_wait_for_target(targetSample, timeoutSeconds);
                output = local_header();

            case 'get_dat'
                output = local_data(arg);

            case Modes.TestBufferCommand.Advance
                local_validate_advance(arg);
                availableSamples = min(capacitySamples, availableSamples + double(arg));
                output = availableSamples;

            otherwise
                error('Unsupported Step 0 test-buffer command: %s', char(command));
        end
    end

    function local_update_available()
        % Real development mode advances with elapsed monotonic time.
        if useLogicalTime
            elapsedSeconds = max(0, double(timeFcn()) - logicalStartTime);
        else
            elapsedSeconds = toc(startedTic);
        end
        elapsedSamples = floor(elapsedSeconds .* RTConfig.Fs);
        initialSamples = RTConfig.DevelopmentSession.Source.InitialAvailableSamples;
        availableSamples = min(capacitySamples, max(availableSamples, ...
            initialSamples + elapsedSamples));
    end

    function hdr = local_header()
        hdr = struct();
        hdr.fsample = RTConfig.Fs;
        hdr.nsamples = availableSamples;
        hdr.nchans = RTConfig.DevelopmentSession.Input.TotalChannelCount;
        hdr.label = channelNames(:);
    end

    function [target, timeoutSeconds] = local_wait_request(arg)
        % Parse FieldTrip [targetSample eventCount timeoutMs] wait arguments.
        target = availableSamples;
        if isnumeric(arg) && ~isempty(arg) && isfinite(arg(1))
            target = max(target, double(arg(1)));
        end
        timeoutMs = RTConfig.Source.FieldTrip.TimeoutMs;
        if isnumeric(arg) && numel(arg) >= 3 && isfinite(arg(3)) && arg(3) >= 0
            timeoutMs = double(arg(3));
        end
        % Convert FieldTrip timeout milliseconds to seconds for waiting.
        timeoutSeconds = timeoutMs ./ 1000;
    end

    function local_wait_for_target(targetSample, timeoutSeconds)
        % Logical tests advance deterministically; real mode waits monotonically.
        if useLogicalTime
            if targetSample > availableSamples
                availableSamples = min(capacitySamples, targetSample);
            end
            return;
        end

        waitTic = tic;
        while availableSamples < targetSample && ...
                availableSamples < capacitySamples && toc(waitTic) < timeoutSeconds
            local_pause(RTConfig.DevelopmentSession.Source.WaitPollSeconds);
            local_update_available();
        end
        local_update_available();
    end

    function local_pause(seconds)
        % The throwing headless seam is unreachable after deterministic return.
        if useLogicalTime && ~isempty(pauseFcn)
            pauseFcn(seconds);
        else
            pause(seconds);
        end
    end

    function payload = local_data(range)
        if ~isnumeric(range) || numel(range) < 2
            error('Step 0 get_dat requires a zero-based inclusive sample range.');
        end
        transportStart = double(range(1));
        transportStop = double(range(2));
        logicalSamples = (transportStart:transportStop) + 1;
        if transportStart < 0 || transportStop < transportStart || ...
                logicalSamples(end) > availableSamples
            error('Step 0 get_dat range is unavailable.');
        end

        nChannels = RTConfig.DevelopmentSession.Input.TotalChannelCount;
        nPrimary = RTConfig.DevelopmentSession.Input.PrimaryMEGChannelCount;
        sampleTime = logicalSamples ./ RTConfig.Fs;
        modulation = 1 + sin(2 .* pi .* ...
            RTConfig.DevelopmentSession.Source.AmplitudeModulationHz .* sampleTime);
        baseTheta = RTConfig.DevelopmentSession.Source.ThetaAmplitude .* modulation .* ...
            sin(2 .* pi .* RTConfig.DevelopmentSession.Source.ThetaFrequencyHz .* sampleTime);
        channelScale = (1:nChannels)' ./ nChannels;
        channelScale((nPrimary + 1):end) = channelScale((nPrimary + 1):end) .* ...
            RTConfig.DevelopmentSession.Source.ReferenceAmplitudeScale;
        phase = (1:nChannels)' .* RTConfig.DevelopmentSession.Source.RandomSeed;
        deterministicNoise = RTConfig.DevelopmentSession.Source.NoiseStd .* ...
            sin(phase + logicalSamples);
        data = channelScale .* baseTheta + deterministicNoise;

        payload = struct();
        payload.buf = data;
        payload.sample_indices = transportStart:transportStop;
    end

    function local_validate_advance(value)
        if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                value < 0 || value ~= round(value)
            error('Step 0 test-buffer advance must be a nonnegative integer.');
        end
    end

end
