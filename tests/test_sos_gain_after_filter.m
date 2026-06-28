function test_sos_gain_after_filter()
% TEST_SOS_GAIN_AFTER_FILTER Check SOS gain placement with nonzero filter state.
%
% USAGE:  test_sos_gain_after_filter()
%
% DESCRIPTION:
%     Compares nf_rt_filter_apply against a local SOS section pass where the
%     scalar SOS gain is applied after filtering with nonzero state.

%% ===== CHECK OPTIONAL TOOLBOX =====
% SOS filtering requires Signal Processing Toolbox helpers.
if ~local_has_signal_toolbox()
    fprintf('[SKIP] test_sos_gain_after_filter: sosfilt/butter unavailable.\n');
    return;
end

%% ===== BUILD FILTER AND REFERENCE =====
% Nonzero initial state catches incorrect gain placement.
rng(2);
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Spatial.NChannels = 1;

Filter = nf_rt_filter_init(RTConfig, 1);
x = randn(1, 400);
initialZi = randn(size(Filter.zi(:, :, 1))) .* 0.01;

[y0, ~] = local_sos_filter_sections(Filter.SOS, x, initialZi);
yCorrect = y0 .* Filter.G;

%% ===== RUN STREAMING FILTER =====
% Inject the same initial state into the RT filter.
Filter.zi(:, :, 1) = initialZi;
RT = nf_rt_init_schema();
RT.Filter = Filter;

chunk = struct();
chunk.Data = x;
chunk.NSamples = numel(x);

[chunkOut, ~] = nf_rt_filter_apply(chunk, RT, RTConfig);

%% ===== CHECK GAIN PLACEMENT =====
% Streaming output should match section filtering followed by scalar gain.
assert(max(abs(chunkOut.Data - yCorrect)) < 1e-10, 'SOS gain was not applied after sosfilt output.');

end

function tf = local_has_signal_toolbox()
% Check whether the needed Signal Processing Toolbox functions are available.
tf = (exist('sosfilt', 'file') ~= 0 || exist('sosfilt', 'builtin') ~= 0) && ...
    (exist('butter', 'file') ~= 0 || exist('butter', 'builtin') ~= 0);
end

function [y, zf] = local_sos_filter_sections(sos, x, zi)
% Apply second-order sections with carried filter state.
y = x;
zf = zi;
for iSection = 1:size(sos, 1)
    b = sos(iSection, 1:3);
    a = sos(iSection, 4:6);
    if a(1) ~= 1
        b = b ./ a(1);
        a = a ./ a(1);
    end
    [y, z] = filter(b, a, y, zi(iSection, :));
    zf(iSection, :) = reshape(z, 1, []);
end
end
