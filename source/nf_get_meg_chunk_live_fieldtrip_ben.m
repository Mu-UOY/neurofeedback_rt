function [chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig)
% NF_GET_MEG_CHUNK_LIVE_FIELDTRIP_BEN Read one live FieldTrip chunk.
%
% USAGE:  [chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig)
%
% DESCRIPTION:
%     Reads one chunk from the configured FieldTrip buffer using explicit
%     zero-based transport and one-based MATLAB logical sample coordinates.
%     This function does not run RT power,
%     baseline, feedback, or trial logic.

%% ===== INITIALIZE OUTPUT =====
chunk = [];

%% ===== WAIT FOR REQUESTED SAMPLES =====
% LastSampleRead is the last consumed MATLAB-facing one-based sample.
logicalStart = Source.LastSampleRead + 1;
logicalStop = Source.LastSampleRead + RTConfig.ChunkSamples;
fieldTripStart = logicalStart - 1;
fieldTripStop = logicalStop - 1;
requestedGetDatRange = [fieldTripStart, fieldTripStop];
indexingMode = 'fieldtrip_zero_based_transport_matlab_one_based_logical_v1';

hdr = nf_live_buffer_call(RTConfig, 'wait_dat', [logicalStop, 0, Source.TimeoutMs]);
headerNSamples = local_header_nsamples(hdr);
Source.LastBufferHeaderNSamples = headerNSamples;
if local_is_buffer_reset(headerNSamples, Source.LastSampleRead)
    Source = local_handle_buffer_reset(Source, headerNSamples, RTConfig);
    return;
end
if ~isfinite(headerNSamples) || headerNSamples < logicalStop
    Source = local_record_timeout(Source);
    return;
end

%% ===== READ FIELDTRIP DATA =====
% FieldTrip get_dat uses zero-based inclusive transport samples.
try
    dat = nf_live_buffer_call(RTConfig, 'get_dat', requestedGetDatRange);
    Xraw = local_extract_data(dat);
    local_validate_transport_indices(dat, requestedGetDatRange);
    local_validate_raw_data(Xraw, Source, RTConfig, requestedGetDatRange);
catch ME
    Source.LastError = 'get_dat_error';
    Source.LastReadStatus = 'get_dat_error';
    rethrow(ME);
end

returnedNSamples = size(Xraw, 2);
logicalSampleIndices = logicalStart:logicalStop;

%% ===== APPLY CANDIDATE CTF CORRECTIONS =====
% The correction function logs unresolved conventions and remains conservative.
[X, CorrectionInfo] = nf_live_apply_ben_ctf_corrections(Xraw, Source, RTConfig);
local_validate_corrected_data(X, Source, RTConfig);

%% ===== PACKAGE CHUNK =====
chunk = struct();
chunk.Data = X;
chunk.SampleIndex = logicalStart;
chunk.SampleIndices = logicalSampleIndices;
chunk.NSamples = size(X, 2);
chunk.ChannelNames = Source.ChannelNamesAfterCorrection;
chunk.Timestamp = now;
chunk.SourceMode = Source.Mode;
chunk.GapBeforeChunkFlag = false;
chunk.CorrectionInfo = CorrectionInfo;
chunk.ReadHeaderNSamples = headerNSamples;
chunk.RequestedGetDatRange = requestedGetDatRange;
chunk.FieldTripReadRange = requestedGetDatRange;
chunk.ReadRangeSamples = requestedGetDatRange;
chunk.LogicalStartSample = logicalStart;
chunk.LogicalStopSample = logicalStop;
chunk.ReturnedNSamples = returnedNSamples;
chunk.IndexingMode = indexingMode;
% BenGetDatRange is a legacy audit alias for the transport range.
chunk.BenGetDatRange = requestedGetDatRange;
chunk.Messages = {['FieldTrip get_dat transport range is zero-based inclusive; ', ...
    'chunk.SampleIndices are MATLAB-facing one-based logical samples. Confirm ', ...
    'this convention in the MEG room before claiming final neural timing.']};
chunk.BenIndexingNote = ['Legacy BenGetDatRange now aliases FieldTripReadRange. ', ...
    'Source.LastSampleRead stores the last consumed one-based logical sample.'];

%% ===== ADVANCE LIVE CURSOR =====
% Advance only after all transport, data, and correction checks pass.
Source.LastClaimedSampleRead = logicalStop;
Source.LastSampleRead = logicalStop;
Source.IndexingMode = indexingMode;
Source.LastError = '';
Source.LastReadStatus = 'success';
Source.ConsecutiveTimeoutCount = 0;

end

function nsamples = local_header_nsamples(hdr)
% Extract sample count from common FieldTrip-compatible header fields.
nsamples = NaN;
if isstruct(hdr) && isfield(hdr, 'nsamples') && isnumeric(hdr.nsamples) && isscalar(hdr.nsamples)
    nsamples = double(hdr.nsamples);
elseif isstruct(hdr) && isfield(hdr, 'nSamples') && isnumeric(hdr.nSamples) && isscalar(hdr.nSamples)
    nsamples = double(hdr.nSamples);
end
end

function tf = local_is_buffer_reset(headerNSamples, lastSampleRead)
% Detect a live buffer counter moving backwards.
tf = isfinite(headerNSamples) && isnumeric(lastSampleRead) && ...
    isscalar(lastSampleRead) && isfinite(lastSampleRead) && ...
    headerNSamples < lastSampleRead;
end

function Source = local_handle_buffer_reset(Source, headerNSamples, RTConfig)
% Error or resync according to the explicit reset policy.
Source.BufferResetCount = local_numeric_field(Source, 'BufferResetCount', 0) + 1;
Source.LastError = 'buffer_reset_detected';
Source.LastReadStatus = 'buffer_reset_detected';
policy = local_get_nested_text(RTConfig, {'Source','FieldTrip','BufferResetPolicy'}, 'error');
if strcmp(policy, 'resync_to_current_end')
    Source.LastSampleRead = headerNSamples;
    Source.LastReadStatus = 'buffer_reset_resynced';
    Source.LastError = '';
    return;
end
error('FieldTrip buffer reset detected: previous cursor %d, current header nsamples %d.', ...
    Source.LastSampleRead, headerNSamples);
end

function Source = local_record_timeout(Source)
% Record timeout diagnostics without advancing the live cursor.
Source.LastError = 'timeout_waiting_for_samples';
Source.LastReadStatus = 'timeout';
Source.TimeoutCount = local_numeric_field(Source, 'TimeoutCount', 0) + 1;
Source.ConsecutiveTimeoutCount = local_numeric_field(Source, 'ConsecutiveTimeoutCount', 0) + 1;
end

function Xraw = local_extract_data(dat)
% Extract numeric data from FieldTrip get_dat output.
if isstruct(dat) && isfield(dat, 'buf')
    Xraw = dat.buf;
else
    Xraw = dat;
end
if ~isnumeric(Xraw) || ndims(Xraw) ~= 2
    error('FieldTrip get_dat returned nonnumeric or nonmatrix data.');
end
Xraw = double(Xraw);
end

function local_validate_transport_indices(dat, requestedRange)
% Validate optional transport indices without using them as logical samples.
if ~isstruct(dat) || ~isfield(dat, 'sample_indices') || isempty(dat.sample_indices)
    return;
end
sampleIndices = double(dat.sample_indices(:)');
expected = requestedRange(1):requestedRange(2);
if ~isequal(sampleIndices, expected)
    error('FieldTrip get_dat sample_indices do not match requested transport range [%d %d].', ...
        requestedRange(1), requestedRange(2));
end
end

function local_validate_raw_data(Xraw, Source, RTConfig, requestedRange)
% Validate raw transport data before correction and cursor advancement.
expectedSamples = RTConfig.ChunkSamples;
if size(Xraw, 2) ~= expectedSamples
    error('Expected %d samples from FieldTrip get_dat, returned %d samples for requested range [%d %d].', ...
        expectedSamples, size(Xraw, 2), requestedRange(1), requestedRange(2));
end
expectedChannels = local_numeric_field(Source, 'NChannels', numel(local_field(Source, 'ChannelNames', {})));
if isfinite(expectedChannels) && expectedChannels > 0 && size(Xraw, 1) ~= expectedChannels
    error('Channel count changed from %d to %d in FieldTrip get_dat output.', ...
        expectedChannels, size(Xraw, 1));
end
if any(~isfinite(Xraw(:)))
    error('FieldTrip get_dat returned nonfinite samples.');
end
end

function local_validate_corrected_data(X, Source, RTConfig)
% Validate corrected data before packaging the chunk.
if ~isnumeric(X) || ndims(X) ~= 2 || size(X, 2) ~= RTConfig.ChunkSamples
    error('Corrected live chunk data has invalid shape.');
end
expectedChannels = numel(local_field(Source, 'ChannelNamesAfterCorrection', {}));
if expectedChannels > 0 && size(X, 1) ~= expectedChannels
    error('Corrected live chunk channel count %d does not match expected %d.', ...
        size(X, 1), expectedChannels);
end
if any(~isfinite(X(:)))
    error('Corrected live chunk contains nonfinite samples.');
end
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function value = local_numeric_field(S, fieldName, defaultValue)
% Read optional numeric scalar.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && isnumeric(S.(fieldName)) && ...
        isscalar(S.(fieldName)) && isfinite(S.(fieldName))
    value = double(S.(fieldName));
end
end

function value = local_get_nested_text(S, path, defaultValue)
% Read optional nested text.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if ischar(cursor) || (isstring(cursor) && isscalar(cursor))
    value = char(cursor);
end
end
