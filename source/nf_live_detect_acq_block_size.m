function BlockInfo = nf_live_detect_acq_block_size(RTConfig, Header0)
% NF_LIVE_DETECT_ACQ_BLOCK_SIZE Detect live acquisition sample increments.
%
% USAGE:  BlockInfo = nf_live_detect_acq_block_size(RTConfig, Header0)
%
% DESCRIPTION:
%     Polls live headers until nsamples advances or the dry-run timeout is
%     reached. Failure to advance is recorded for the caller's pass/fail
%     decision and is not thrown here.

%% ===== INITIALIZE OUTPUT =====
Modes = nf_modes();
timeoutSecs = RTConfig.LiveDryRun.TimeoutSecs;
if local_get_logical(RTConfig, {'DevelopmentSession','Enabled'}, false)
    timeoutSecs = RTConfig.DevelopmentSession.Source.ReadinessTimeoutSeconds;
end
pollSeconds = RTConfig.Source.FieldTrip.HeaderPollSeconds;
fs = local_get_numeric(Header0, {'Fs'}, local_get_numeric(RTConfig, {'Fs'}, NaN));
prevSample = Header0.NSamples;

BlockInfo = struct();
BlockInfo.InitialNSamples = prevSample;
BlockInfo.SecondNSamples = prevSample;
BlockInfo.SampleCountAdvanced = false;
BlockInfo.AcquisitionBlockSamples = NaN;
BlockInfo.AcquisitionBlockSeconds = NaN;
BlockInfo.Timeout = false;
BlockInfo.Messages = {};
BlockInfo.AdvancementCount = 0;
BlockInfo.Pass = false;
BlockInfo.Status = Modes.ReadinessStatus.Fail;

%% ===== HANDLE STRICT STEP 0 TEST READINESS =====
isStep0Headless = nf_is_strict_step0_headless_contract(RTConfig);
if isStep0Headless
    advanceSamples = local_get_numeric(RTConfig, ...
        {'DevelopmentSession','Source','ReadinessAdvanceSamples'}, NaN);
    nf_live_buffer_call(RTConfig, Modes.TestBufferCommand.Advance, advanceSamples);
    hdr = nf_live_buffer_call(RTConfig, 'get_hdr', []);
    BlockInfo = local_record_advance(BlockInfo, prevSample, ...
        local_header_nsamples(hdr), fs);
    if ~BlockInfo.Pass
        BlockInfo.Timeout = true;
        BlockInfo.Messages{end+1} = ...
            'Step 0 deterministic readiness probe did not observe positive advancement.';
    end
    return;
end

%% ===== POLL HEADER ADVANCE =====
% Use the same buffer wrapper used by all live source helpers.
tStart = tic;
while toc(tStart) <= timeoutSecs
    hdr = nf_live_buffer_call(RTConfig, 'get_hdr', []);
    nsamples = local_header_nsamples(hdr);
    if isfinite(nsamples)
        BlockInfo.SecondNSamples = nsamples;
        if nsamples > prevSample
            BlockInfo = local_record_advance(BlockInfo, prevSample, nsamples, fs);
            return;
        end
    end
    pause(pollSeconds);
end

%% ===== RECORD TIMEOUT =====
% The channel-check runner converts this into a user-facing FAIL result.
BlockInfo.Timeout = true;
BlockInfo.Messages{end+1} = 'Sample count did not advance before LiveDryRun.TimeoutSecs.';

end

function nsamples = local_header_nsamples(hdr)
% Extract nsamples from a raw FieldTrip header.
nsamples = NaN;
if isstruct(hdr) && isfield(hdr, 'nsamples') && isnumeric(hdr.nsamples) && ...
        isscalar(hdr.nsamples) && isfinite(hdr.nsamples)
    nsamples = double(hdr.nsamples);
elseif isstruct(hdr) && isfield(hdr, 'nSamples') && isnumeric(hdr.nSamples) && ...
        isscalar(hdr.nSamples) && isfinite(hdr.nSamples)
    nsamples = double(hdr.nSamples);
end
end

function BlockInfo = local_record_advance(BlockInfo, previous, current, fs)
% Normalize readiness evidence and fail closed on malformed/nonpositive data.
BlockInfo.SecondNSamples = current;
if ~isfinite(previous) || ~isfinite(current) || current <= previous
    return;
end
BlockInfo.SampleCountAdvanced = true;
BlockInfo.AcquisitionBlockSamples = current - previous;
BlockInfo.AdvancementCount = BlockInfo.AcquisitionBlockSamples;
if isfinite(fs) && fs > 0
    BlockInfo.AcquisitionBlockSeconds = BlockInfo.AcquisitionBlockSamples ./ fs;
end
BlockInfo.Pass = true;
BlockInfo.Status = nf_modes().ReadinessStatus.Pass;
end

function value = local_get_numeric(S, path, defaultValue)
% Read optional nested numeric scalar.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
if isnumeric(cursor) && isscalar(cursor) && isfinite(cursor)
    value = double(cursor);
end
end

function value = local_get_logical(S, path, defaultValue)
% Read optional nested logical scalar.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if islogical(cursor) && isscalar(cursor)
    value = cursor;
elseif isnumeric(cursor) && isscalar(cursor) && isfinite(cursor)
    value = cursor ~= 0;
end
end
