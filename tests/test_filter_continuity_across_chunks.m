function test_filter_continuity_across_chunks()
% TEST_FILTER_CONTINUITY_ACROSS_CHUNKS Compare chunked SOS filtering to full filtering.
%
% USAGE:  test_filter_continuity_across_chunks()
%
% DESCRIPTION:
%     Compares one full causal SOS filtering pass with the same data filtered
%     chunk by chunk while carrying filter state.

%% ===== CHECK OPTIONAL TOOLBOX =====
% SOS filtering requires Signal Processing Toolbox helpers.
if ~local_has_signal_toolbox()
    fprintf('[SKIP] test_filter_continuity_across_chunks: sosfilt/butter unavailable.\n');
    return;
end

%% ===== CONFIGURE FILTER TEST =====
% Non-divisible chunk length exercises state carryover across uneven chunks.
rng(1);
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Debug.CheckRTSchema = false;
RTConfig.Debug.CheckMeasureSchema = false;
RTConfig.Fs = 1200;
RTConfig.ChunkSamples = 37;
RTConfig.PowerWindowSamples = 120;
RTConfig.BufferSamples = 240;
RTConfig.Spatial.NChannels = 1;

Filter = nf_rt_filter_init(RTConfig, 1);
x = randn(1, 1000);

%% ===== FILTER FULL SIGNAL =====
% This is the reference causal output.
RTFull = nf_rt_init_schema();
RTFull.Filter = Filter;
chunkFull = struct();
chunkFull.Data = x;
chunkFull.NSamples = numel(x);
[chunkFull, ~] = nf_rt_filter_apply(chunkFull, RTFull, RTConfig);
yFull = chunkFull.Data;

%% ===== FILTER SIGNAL IN CHUNKS =====
% Streaming output should match the full causal pass exactly within tolerance.
RT = nf_rt_init_schema();
RT.Filter = Filter;
yStream = zeros(size(x));
pos = 1;
while pos <= numel(x)
    stop = min(pos + RTConfig.ChunkSamples - 1, numel(x));
    chunk = struct();
    chunk.Data = x(pos:stop);
    chunk.NSamples = stop - pos + 1;
    [chunkOut, RT] = nf_rt_filter_apply(chunk, RT, RTConfig);
    yStream(pos:stop) = chunkOut.Data;
    pos = stop + 1;
end

%% ===== CHECK CONTINUITY =====
% Any difference indicates filter state was not carried correctly.
assert(max(abs(yFull - yStream)) < 1e-10, 'Chunked filtering differs from full causal filtering.');

end

function tf = local_has_signal_toolbox()
% Check whether the needed Signal Processing Toolbox functions are available.
tf = (exist('sosfilt', 'file') ~= 0 || exist('sosfilt', 'builtin') ~= 0) && ...
    (exist('butter', 'file') ~= 0 || exist('butter', 'builtin') ~= 0);
end
