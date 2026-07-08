function [chunk, Source] = nf_get_meg_chunk(Source, RTConfig)
% NF_GET_MEG_CHUNK Return the next MEG chunk from a source adapter.
%
% USAGE:  [chunk, Source] = nf_get_meg_chunk(Source, RTConfig)
%
% DESCRIPTION:
%     Reads the next chunk from a simulated source, optionally skips chunks
%     to emulate dropped data, packages chunk metadata, and advances the
%     source cursor.

%% ===== INITIALIZE OUTPUT =====
% Empty chunk means the source is exhausted.
chunk = [];

%% ===== CHECK SOURCE MODE =====
% Live FieldTrip dispatch stays outside the simulated replay path.
Modes = nf_modes();
if strcmp(Source.Mode, Modes.Source.LiveFieldTrip)
    if ~isfield(Source, 'LiveAdapter') || ...
            ~strcmp(Source.LiveAdapter, Modes.LiveAdapter.BenFieldTrip)
        error('live_fieldtrip chunk reading requires Source.LiveAdapter = ben_fieldtrip_buffer.');
    end
    [chunk, Source] = nf_get_meg_chunk_live_fieldtrip_ben(Source, RTConfig);
    return;
end
if strcmp(Source.Mode, 'live_brainstorm')
    error('live_brainstorm chunk reading is not implemented in Step 3A.');
end
if strcmp(Source.Mode, Modes.Source.MockLiveBuffer)
    error('mock_live_buffer chunk reading is not implemented in Step 3A.');
end

%% ===== CHECK SIMULATED SOURCE MODE =====
% Simulated source reading remains unchanged.
simulatedModes = {'offline_full','simulated_online','simulated_resting','simulated_trial'};
if ~ismember(Source.Mode, simulatedModes)
    error('Live source reading is not implemented in the first code version.');
end

%% ===== HANDLE EXHAUSTED SOURCE =====
% Stop once the cursor moves beyond the configured end sample.
if Source.CurrentSample > Source.EndSample
    return;
end

%% ===== SIMULATE DROPPED CHUNKS =====
% Drop simulation advances over one or more whole chunks before reading data.
dropCount = 0;
dropSamples = 0;
while Source.SimDrop.Enabled && Source.CurrentSample <= Source.EndSample
    Source.ChunkCounter = Source.ChunkCounter + 1;

    shouldDrop = local_should_drop_chunk(Source);
    if ~shouldDrop
        break;
    end

    dropStart = Source.CurrentSample;
    dropStop = min(dropStart + Source.ChunkSamples - 1, Source.EndSample);
    Source.CurrentSample = dropStop + 1;
    dropCount = dropCount + 1;
    dropSamples = dropSamples + dropStop - dropStart + 1;
end
Source.LastDroppedChunks = dropCount;
Source.LastDroppedSamples = dropSamples;

% If dropping consumed the remaining samples, return empty.
if Source.CurrentSample > Source.EndSample
    return;
end

% When drop simulation is disabled, still count the emitted chunk.
if ~Source.SimDrop.Enabled
    Source.ChunkCounter = Source.ChunkCounter + 1;
end

%% ===== SELECT CHUNK RANGE =====
% Clamp the final chunk to Source.EndSample.
startSample = Source.CurrentSample;
stopSample = min(startSample + Source.ChunkSamples - 1, Source.EndSample);

%% ===== PACKAGE CHUNK =====
% Chunk metadata travels with the data through RT validation and sync checks.
chunk = struct();
chunk.Data = Source.Data(:, startSample:stopSample);
chunk.SampleIndex = startSample;
chunk.SampleIndices = startSample:stopSample;
chunk.NSamples = stopSample - startSample + 1;
chunk.ChannelNames = Source.ChannelNames;
chunk.Timestamp = NaN;
chunk.SourceMode = Source.Mode;
chunk.GapBeforeChunkFlag = dropCount > 0;
chunk.SimulatedDropFlag = dropCount > 0;
chunk.DroppedChunkFlag = false;
chunk.SimulatedDroppedChunks = dropCount;
chunk.SimulatedDroppedSamples = dropSamples;

%% ===== ADVANCE SOURCE CURSOR =====
% The next call starts immediately after this chunk.
Source.CurrentSample = stopSample + 1;

%% ===== CHECK INTERNAL CONSISTENCY =====
% These errors indicate a source adapter bug, not user input.
if chunk.NSamples ~= size(chunk.Data, 2)
    error('Internal source error: chunk.NSamples does not match chunk.Data.');
end
if numel(chunk.SampleIndices) ~= chunk.NSamples
    error('Internal source error: chunk.SampleIndices length mismatch.');
end

%% ===== WARN ABOUT UNSUPPORTED OPTIONS =====
% Jitter is declared in config but not implemented in this first version.
if isfield(RTConfig.Simulation, 'EnableJitter') && RTConfig.Simulation.EnableJitter
    warning('Simulation jitter is declared in RTConfig but not implemented in the first code version.');
end

end

function shouldDrop = local_should_drop_chunk(Source)
% Deterministic schedules take priority over probabilistic drops.
if isfield(Source.SimDrop, 'DropChunkIndices') && ~isempty(Source.SimDrop.DropChunkIndices)
    shouldDrop = any(Source.SimDrop.DropChunkIndices == Source.ChunkCounter);
    return;
end

shouldDrop = rand < Source.SimDrop.Probability;
end
