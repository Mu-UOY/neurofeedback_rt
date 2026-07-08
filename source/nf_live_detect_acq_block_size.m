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
timeoutSecs = local_get_numeric(RTConfig, {'LiveDryRun','TimeoutSecs'}, 5);
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

%% ===== POLL HEADER ADVANCE =====
% Use the same buffer wrapper used by all live source helpers.
tStart = tic;
while toc(tStart) <= timeoutSecs
    hdr = nf_live_buffer_call(RTConfig, 'get_hdr', []);
    nsamples = local_header_nsamples(hdr);
    if isfinite(nsamples)
        BlockInfo.SecondNSamples = nsamples;
        if nsamples > prevSample
            BlockInfo.SampleCountAdvanced = true;
            BlockInfo.AcquisitionBlockSamples = nsamples - prevSample;
            if isfinite(fs) && fs > 0
                BlockInfo.AcquisitionBlockSeconds = BlockInfo.AcquisitionBlockSamples ./ fs;
            end
            return;
        end
    end
    pause(0.05);
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
end
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
