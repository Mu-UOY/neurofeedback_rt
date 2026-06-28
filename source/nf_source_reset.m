function Source = nf_source_reset(Source)
% NF_SOURCE_RESET Reset a simulated source to its first sample.
%
% USAGE:  Source = nf_source_reset(Source)
%
% DESCRIPTION:
%     Moves a simulated source cursor back to StartSample and clears the
%     remembered drop count so replay can be repeated from the beginning.

%% ===== RESET SOURCE CURSOR =====
% Rewind the source to its configured first sample.
Source.CurrentSample = Source.StartSample;

%% ===== RESET DROP STATE =====
% Clear the last-read drop count before the next replay.
Source.LastDroppedChunks = 0;

end
