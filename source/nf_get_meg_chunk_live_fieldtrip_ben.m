function [chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig)
% NF_GET_MEG_CHUNK_LIVE_FIELDTRIP_BEN Read one Ben-indexed live chunk.
%
% USAGE:  [chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig)
%
% DESCRIPTION:
%     Reads one chunk from the configured FieldTrip buffer using Benjamin's
%     preserved indexing convention. This function does not run RT power,
%     baseline, feedback, or trial logic.

%% ===== INITIALIZE OUTPUT =====
chunk = [];

%% ===== WAIT FOR REQUESTED SAMPLES =====
% SampleIndex is the MATLAB-facing logical start; get_dat keeps Benjamin's
% historical range convention until MEG-room verification with Marc.
startSample = Source.LastSampleRead + 1;
stopSample = Source.LastSampleRead + RTConfig.ChunkSamples;

hdr = nf_live_buffer_call(RTConfig, 'wait_dat', [stopSample, 0, Source.TimeoutMs]);
if ~isstruct(hdr) || ~isfield(hdr, 'nsamples') || hdr.nsamples < stopSample
    Source.LastError = 'timeout_waiting_for_samples';
    return;
end

%% ===== READ FIELDTRIP DATA =====
% Do not silently change this range; it preserves Benjamin's convention.
benGetDatRange = Source.LastSampleRead - 1 + [1, RTConfig.ChunkSamples];
dat = nf_live_buffer_call(RTConfig, 'get_dat', benGetDatRange);
if isstruct(dat) && isfield(dat, 'buf')
    Xraw = double(dat.buf);
else
    Xraw = double(dat);
end

sampleIndices = startSample:stopSample;
if isstruct(dat) && isfield(dat, 'sample_indices') && ...
        isfield(RTConfig.Source.FieldTrip, 'TestBufferFcn') && ...
        ~isempty(RTConfig.Source.FieldTrip.TestBufferFcn)
    sampleIndices = double(dat.sample_indices);
end

%% ===== APPLY CANDIDATE CTF CORRECTIONS =====
% The correction function logs unresolved conventions and remains conservative.
[X, CorrectionInfo] = nf_live_apply_ben_ctf_corrections(Xraw, Source, RTConfig);

%% ===== PACKAGE CHUNK =====
chunk = struct();
chunk.Data = X;
chunk.SampleIndex = sampleIndices(1);
chunk.SampleIndices = sampleIndices;
chunk.NSamples = size(X, 2);
chunk.ChannelNames = Source.ChannelNamesAfterCorrection;
chunk.Timestamp = now;
chunk.SourceMode = Source.Mode;
chunk.GapBeforeChunkFlag = false;
chunk.CorrectionInfo = CorrectionInfo;
chunk.ReadHeaderNSamples = hdr.nsamples;
chunk.BenGetDatRange = benGetDatRange;
chunk.BenIndexingNote = ['chunk.SampleIndex is LastSampleRead+1, while get_dat range uses ', ...
    'Source.LastSampleRead - 1 + [1 ChunkSamples]. This preserves the Benjamin ', ...
    'indexing convention until confirmed in the MEG room.'];

%% ===== ADVANCE LIVE CURSOR =====
% Repeated live chunk smoke testing is Step 3B; this reader only advances one call.
Source.LastSampleRead = stopSample;
Source.LastError = '';

end
