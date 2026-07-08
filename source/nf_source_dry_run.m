function DryRun = nf_source_dry_run(Source, RTConfig, varargin)
% NF_SOURCE_DRY_RUN Run a short acquisition-only source dry run.
%
% USAGE:  DryRun = nf_source_dry_run(Source, RTConfig)
%
% DESCRIPTION:
%     Records live header/sample-count progress without calling
%     nf_rt_process_chunk, baseline, trial, or feedback code.

%% ===== PARSE OPTIONS =====
% One optional read is useful later, but defaults off for Step 3A checks.
readOneChunk = false;
for iArg = 1:2:numel(varargin)
    name = varargin{iArg};
    if strcmpi(name, 'ReadOneChunk') && iArg < numel(varargin)
        readOneChunk = logical(varargin{iArg + 1});
    end
end

%% ===== RECORD HEADER AND BLOCK INFO =====
% Reuse the same acquisition block detector used by source initialization.
Header0 = Source.Header;
BlockInfo = nf_live_detect_acq_block_size(RTConfig, Header0);

DryRun = struct();
DryRun.Mode = Source.Mode;
DryRun.LiveAdapter = Source.LiveAdapter;
DryRun.Fs = Source.Fs;
DryRun.NChannels = Source.NChannels;
DryRun.ChannelNames = Source.ChannelNames;
DryRun.InitialNSamples = BlockInfo.InitialNSamples;
DryRun.SecondNSamples = BlockInfo.SecondNSamples;
DryRun.SampleCountAdvanced = BlockInfo.SampleCountAdvanced;
DryRun.AcquisitionBlockSamples = BlockInfo.AcquisitionBlockSamples;
DryRun.AcquisitionBlockSeconds = BlockInfo.AcquisitionBlockSeconds;
DryRun.BlockInfo = BlockInfo;
DryRun.ReadOneChunk = readOneChunk;
DryRun.Chunk = [];
DryRun.Messages = BlockInfo.Messages;

%% ===== OPTIONALLY READ ONE CHUNK =====
% This still avoids RT processing; repeated smoke testing belongs to Step 3B.
if readOneChunk
    [DryRun.Chunk, Source] = nf_get_meg_chunk(Source, RTConfig); %#ok<ASGLU>
end

end
