function test_step0_development_producer_wait_dat()
% TEST_STEP0_DEVELOPMENT_PRODUCER_WAIT_DAT Verify logical and real waits.

%% ===== HEADLESS WAIT IS DETERMINISTIC =====
RTConfig = nf_test_step0_config(tempname);
RTConfig.DevelopmentSession.TestHooks.PauseFcn = @local_fail_if_paused;
RTConfig = nf_finalize_config(RTConfig);
RTConfig.Source.FieldTrip.TestBufferFcn = ...
    nf_make_development_fieldtrip_buffer(RTConfig);
bufferFcn = RTConfig.Source.FieldTrip.TestBufferFcn;
initial = bufferFcn('get_hdr', [], '', []);
target = initial.nsamples + RTConfig.ChunkSamples;
logicalTimeBefore = RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox.LogicalTime;
headless = bufferFcn('wait_dat', ...
    [target 0 RTConfig.Source.FieldTrip.TimeoutMs], '', []);
assert(headless.nsamples == target);
assert(RTConfig.DevelopmentSession.TestHooks.FakePsychtoolbox.LogicalTime == ...
    logicalTimeBefore);

%% ===== REAL WAIT OBSERVES ELAPSED TIME =====
realConfig = RTConfig;
realConfig.DevelopmentSession.TestHooks.TimeFcn = [];
realConfig.DevelopmentSession.TestHooks.PauseFcn = [];
realConfig.Source.FieldTrip.TestBufferFcn = [];
realBuffer = nf_make_development_fieldtrip_buffer(realConfig);
header0 = realBuffer('get_hdr', [], '', []);
elapsedTarget = header0.nsamples + ceil(realConfig.Fs .* ...
    realConfig.DevelopmentSession.Source.WaitPollSeconds .* 3);
tReal = tic;
header1 = realBuffer('wait_dat', [elapsedTarget 0 ...
    realConfig.Source.FieldTrip.TimeoutMs], '', []);
realElapsed = toc(tReal);
assert(realElapsed >= realConfig.DevelopmentSession.Source.WaitPollSeconds);
assert(header1.nsamples >= elapsedTarget);

%% ===== TIMEOUT AND CAPACITY FAIL CLOSED =====
timeoutTarget = header1.nsamples + realConfig.ChunkSamples;
timeoutMs = realConfig.DevelopmentSession.Source.WaitPollSeconds .* 1000;
timedOut = realBuffer('wait_dat', [timeoutTarget 0 timeoutMs], '', []);
assert(timedOut.nsamples < timeoutTarget);

capacityConfig = RTConfig;
capacityConfig.DevelopmentSession.Source.InitialAvailableSamples = 0;
capacityConfig.DevelopmentSession.Source.CapacitySamples = ...
    capacityConfig.DevelopmentSession.Source.ReadinessAdvanceSamples;
capacityBuffer = nf_make_development_fieldtrip_buffer(capacityConfig);
capacityTarget = capacityConfig.DevelopmentSession.Source.CapacitySamples + ...
    capacityConfig.ChunkSamples;
capacityHeader = capacityBuffer('wait_dat', [capacityTarget 0 ...
    capacityConfig.Source.FieldTrip.TimeoutMs], '', []);
assert(capacityHeader.nsamples <= capacityConfig.DevelopmentSession.Source.CapacitySamples);

%% ===== CONSUMER CURSOR ADVANCES ONLY AFTER SUCCESSFUL DATA =====
cursorConfig = nf_test_step0_config(tempname);
Source = nf_source_init(nf_modes().Source.LiveFieldTrip, [], cursorConfig);
cursorBefore = Source.LastSampleRead;
[chunk, Source] = nf_get_meg_chunk(Source, cursorConfig);
assert(~isempty(chunk));
assert(Source.LastSampleRead == cursorBefore + cursorConfig.ChunkSamples);

blockedConfig = nf_test_step0_config(tempname);
blockedBase = blockedConfig.Source.FieldTrip.TestBufferFcn;
nDataWaits = 0;
blockedConfig.Source.FieldTrip.TestBufferFcn = @local_block_after_first_wait;
blockedSource = nf_source_init(nf_modes().Source.LiveFieldTrip, [], blockedConfig);
[firstChunk, blockedSource] = nf_get_meg_chunk(blockedSource, blockedConfig);
assert(~isempty(firstChunk));
blockedCursor = blockedSource.LastSampleRead;
[unavailableChunk, blockedSource] = nf_get_meg_chunk(blockedSource, blockedConfig);
assert(isempty(unavailableChunk));
assert(blockedSource.LastSampleRead == blockedCursor);

    function output = local_block_after_first_wait(command, arg, host, port)
        if strcmp(char(command), 'wait_dat')
            nDataWaits = nDataWaits + 1;
            if nDataWaits > 1
                output = blockedBase('get_hdr', [], host, port);
                return;
            end
        end
        output = blockedBase(command, arg, host, port);
    end
end

function local_fail_if_paused(varargin) %#ok<INUSD>
error('neurofeedback:test:unexpectedHeadlessPause', ...
    'Headless wait_dat invoked the forbidden pause seam.');
end
