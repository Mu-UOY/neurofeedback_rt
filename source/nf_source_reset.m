function Source = nf_source_reset(Source)
% NF_SOURCE_RESET Reset a simulated source to its first sample.
%
% USAGE:  Source = nf_source_reset(Source)
%
% DESCRIPTION:
%     Moves a simulated source cursor back to StartSample and clears replay
%     state so deterministic and seeded probabilistic source replay can be
%     repeated from the beginning.

%% ===== RESET SOURCE CURSOR =====
% Rewind the source to its configured first sample.
Source.CurrentSample = Source.StartSample;

%% ===== RESET DROP STATE =====
% Clear replay-dependent counters before the next pass.
if isfield(Source, 'ChunkCounter')
    Source.ChunkCounter = 0;
end
if isfield(Source, 'LastDroppedChunks')
    Source.LastDroppedChunks = 0;
end
if isfield(Source, 'LastDroppedSamples')
    Source.LastDroppedSamples = 0;
end

%% ===== RESET SEEDED RANDOMNESS =====
% Reapply the configured seed so probabilistic drop replay is reproducible.
if isfield(Source, 'SimDrop') && ...
        isfield(Source.SimDrop, 'Enabled') && Source.SimDrop.Enabled && ...
        isfield(Source.SimDrop, 'RandomSeed') && ...
        ~isempty(Source.SimDrop.RandomSeed) && ...
        isfinite(Source.SimDrop.RandomSeed)
    rng(Source.SimDrop.RandomSeed);
end

end
