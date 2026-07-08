function Source = nf_source_init(Mode, Data, RTConfig)
% NF_SOURCE_INIT Initialize a MEG data source adapter.
%
% USAGE:  Source = nf_source_init(Mode, Data, RTConfig)
%
% DESCRIPTION:
%     Builds a simulated source adapter around canonical Data.X, resolves the
%     requested sample range, copies channel labels, and stores simulation
%     settings used when chunks are read.

%% ===== PARSE SOURCE MODE =====
% Empty Mode falls back to the configured source mode.
if nargin < 1 || isempty(Mode)
    Mode = RTConfig.Source.Mode;
end

%% ===== CHECK SOURCE MODE =====
% Live FieldTrip dispatch is acquisition-only and must avoid Data.X checks.
simulatedModes = {'offline_full','simulated_online','simulated_resting','simulated_trial'};
Mode = char(Mode);
Modes = nf_modes();

if strcmp(Mode, 'live_fieldtrip')
    if ~isfield(RTConfig.Source, 'LiveAdapter') || ...
            ~strcmp(RTConfig.Source.LiveAdapter, Modes.LiveAdapter.BenFieldTrip)
        error('live_fieldtrip requires Source.LiveAdapter = ben_fieldtrip_buffer.');
    end
    Source = nf_source_init_live_fieldtrip_ben(RTConfig);
    return;
end
if strcmp(Mode, 'live_brainstorm')
    error('live_brainstorm source initialization is not implemented in Step 3A.');
end
if strcmp(Mode, 'mock_live_buffer')
    error('mock_live_buffer source initialization is not implemented in Step 3A.');
end
if ~ismember(Mode, simulatedModes)
    error('Unknown source mode: %s', Mode);
end

%% ===== CHECK INPUT DATA =====
% Simulated sources replay samples from Data.X.
if ~isstruct(Data) || ~isfield(Data, 'X') || ~isnumeric(Data.X)
    error('Data.X is required for simulated source modes.');
end
if isfield(Data, 'Fs') && abs(Data.Fs - RTConfig.Fs) > 1e-9
    error('Data.Fs (%g) does not match RTConfig.Fs (%g).', Data.Fs, RTConfig.Fs);
end

nSamples = size(Data.X, 2);

%% ===== RESOLVE SAMPLE RANGE =====
% Clamp configured source bounds to the available dataset length.
startSample = RTConfig.Source.StartSample;
if isempty(startSample)
    startSample = 1;
end
SourceStartSample = max(1, round(startSample));

endSample = RTConfig.Source.EndSample;
if isempty(endSample) || isinf(endSample)
    endSample = nSamples;
end
SourceEndSample = min(nSamples, round(endSample));
if SourceEndSample < SourceStartSample
    error('Invalid source sample range: [%d %d].', SourceStartSample, SourceEndSample);
end

%% ===== INITIALIZE SOURCE STRUCT =====
% CurrentSample is the mutable cursor advanced by nf_get_meg_chunk.
Source = struct();
Source.Mode = Mode;
Source.Data = Data.X;
Source.Fs = RTConfig.Fs;
Source.StartSample = SourceStartSample;
Source.EndSample = SourceEndSample;
Source.CurrentSample = Source.StartSample;
Source.ChunkSamples = RTConfig.ChunkSamples;
Source.ChunkCounter = 0;

%% ===== COPY CHANNEL NAMES =====
% Missing labels get deterministic CH001-style names.
if isfield(Data, 'ChannelNames')
    Source.ChannelNames = Data.ChannelNames;
else
    Source.ChannelNames = local_default_channel_names(size(Data.X, 1));
end

%% ===== COPY SIMULATION SETTINGS =====
% Drop settings are consumed by nf_get_meg_chunk.
Source.SimDrop.Enabled = RTConfig.Simulation.EnableDroppedChunks;
Source.SimDrop.Probability = RTConfig.Simulation.DropProbability;
if isfield(RTConfig.Simulation, 'DropChunkIndices') && Source.SimDrop.Enabled
    Source.SimDrop.DropChunkIndices = unique(round(RTConfig.Simulation.DropChunkIndices(:)'));
else
    Source.SimDrop.DropChunkIndices = [];
end
if isfield(RTConfig.Simulation, 'RandomSeed')
    Source.SimDrop.RandomSeed = RTConfig.Simulation.RandomSeed;
else
    Source.SimDrop.RandomSeed = [];
end
Source.LastDroppedChunks = 0;
Source.LastDroppedSamples = 0;

% Seed probabilistic simulation when requested. Scheduled drops are unaffected.
if Source.SimDrop.Enabled && ~isempty(Source.SimDrop.RandomSeed) && ...
        isfinite(Source.SimDrop.RandomSeed)
    rng(Source.SimDrop.RandomSeed);
end

end

function names = local_default_channel_names(nChannels)
% Create deterministic labels when a simulated dataset does not provide them.
names = cell(1, nChannels);
for i = 1:nChannels
    names{i} = sprintf('CH%03d', i);
end
end
