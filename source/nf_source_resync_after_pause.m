function [Source, ResyncInfo] = nf_source_resync_after_pause(Source, RTConfig, phase)
% NF_SOURCE_RESYNC_AFTER_PAUSE Discard stale live backlog after a pause.
%
% USAGE:  [Source, ResyncInfo] = nf_source_resync_after_pause(Source, RTConfig, phase)

%% ===== INITIALIZE RESULT =====
% The schema is saved in live self-test audit reports.
if nargin < 3 || isempty(phase)
    phase = '';
end
Modes = nf_modes();
policy = local_get_text(RTConfig, {'Source','FieldTrip','AfterManualStartBacklogPolicy'}, ...
    Modes.BufferBacklog.DiscardAccumulated);

ResyncInfo = struct();
ResyncInfo.Type = 'manual_start_backlog_resync';
ResyncInfo.Phase = char(phase);
ResyncInfo.Policy = policy;
ResyncInfo.Applied = false;
ResyncInfo.PreviousSample = local_current_sample(Source);
ResyncInfo.LatestSample = ResyncInfo.PreviousSample;
ResyncInfo.SkippedSamples = 0;
ResyncInfo.Message = '';

%% ===== HANDLE PRESERVE POLICY =====
% PreserveCursor is useful for deterministic test replay.
if strcmp(policy, Modes.BufferBacklog.PreserveCursor)
    ResyncInfo.Message = 'Source cursor preserved after pause.';
    return;
end

%% ===== HANDLE NON-LIVE SOURCES =====
% Simulated sources do not have FieldTrip backlog.
if ~isstruct(Source) || ~isfield(Source, 'Mode') || ...
        ~strcmp(Source.Mode, Modes.Source.LiveFieldTrip)
    ResyncInfo.Message = 'No live FieldTrip backlog resync needed.';
    return;
end

%% ===== READ LATEST LIVE HEADER =====
% The next chunk read will wait for samples after LatestSample.
hdr = nf_live_buffer_call(RTConfig, 'get_hdr', []);
latestSample = local_header_nsamples(hdr, ResyncInfo.PreviousSample);
ResyncInfo.LatestSample = latestSample;
ResyncInfo.SkippedSamples = max(0, latestSample - ResyncInfo.PreviousSample);

if isfield(Source, 'LastSampleRead')
    Source.LastSampleRead = latestSample;
end
if isfield(Source, 'InitialSample')
    Source.InitialSample = latestSample;
end
if isfield(Source, 'Header') && isstruct(Source.Header) && isfield(Source.Header, 'NSamples')
    Source.Header.NSamples = latestSample;
end

ResyncInfo.Applied = true;
ResyncInfo.Message = sprintf('Discarded %d pause-backlog samples.', ResyncInfo.SkippedSamples);

end

function sample = local_current_sample(Source)
% Read the live cursor sample with fallbacks.
sample = NaN;
if isstruct(Source) && isfield(Source, 'LastSampleRead') && isnumeric(Source.LastSampleRead)
    sample = double(Source.LastSampleRead);
elseif isstruct(Source) && isfield(Source, 'CurrentSample') && isnumeric(Source.CurrentSample)
    sample = double(Source.CurrentSample);
end
end

function sample = local_header_nsamples(hdr, defaultValue)
% Extract nsamples from FieldTrip header.
sample = defaultValue;
if isstruct(hdr) && isfield(hdr, 'nsamples') && isnumeric(hdr.nsamples) && ...
        isscalar(hdr.nsamples) && isfinite(hdr.nsamples)
    sample = double(hdr.nsamples);
elseif isstruct(hdr) && isfield(hdr, 'nSamples') && isnumeric(hdr.nSamples) && ...
        isscalar(hdr.nSamples) && isfinite(hdr.nSamples)
    sample = double(hdr.nSamples);
end
end

function value = local_get_text(S, path, defaultValue)
% Read optional nested text.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if ischar(cursor) || isstring(cursor)
    value = char(cursor);
end
end
