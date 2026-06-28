function [Xf, Info] = nf_apply_offline_iir_sos(X, RTConfig)
% NF_APPLY_OFFLINE_IIR_SOS Apply the offline causal IIR/SOS bandpass.
%
% USAGE:  [Xf, Info] = nf_apply_offline_iir_sos(X, RTConfig)
%
% DESCRIPTION:
%     Designs the same Butterworth SOS bandpass used by the streaming
%     filter, applies it causally to a full offline signal, and applies the
%     scalar SOS gain after section filtering.

%% ===== CHECK INPUTS =====
% X is already expected to be in post-spatial signal space.
if ~isnumeric(X) || ndims(X) ~= 2
    error('X must be a numeric [nSignals x nSamples] matrix.');
end

%% ===== DESIGN SOS FILTER =====
% Keep this design convention synchronized with nf_rt_filter_init.m.
order = 4;
if isfield(RTConfig, 'Filter') && isfield(RTConfig.Filter, 'Order') && ~isempty(RTConfig.Filter.Order)
    order = RTConfig.Filter.Order;
end

if exist('butter', 'file') == 0 && exist('butter', 'builtin') == 0
    error('Offline IIR/SOS filtering requires butter.');
end

Wn = RTConfig.TargetBand ./ (RTConfig.Fs / 2);
try
    [sos, g] = butter(order, Wn, 'bandpass', 'sos');
catch ME
    if exist('zp2sos', 'file') == 0 && exist('zp2sos', 'builtin') == 0
        error('Could not design SOS Butterworth filter: %s', ME.message);
    end
    [z, p, k] = butter(order, Wn, 'bandpass');
    [sos, g] = zp2sos(z, p, k);
end

if ~isscalar(g)
    error('Expected scalar SOS gain g. Per-section gains are not supported.');
end

%% ===== FILTER FULL SIGNAL =====
% This follows nf_rt_filter_init/nf_rt_filter_apply for iir_sos mode:
% SOS sections are cascaded causally, and scalar gain g is applied after
% the final section output.
Xf = zeros(size(X));
for iSignal = 1:size(X, 1)
    zi = zeros(size(sos, 1), 2);
    [ys, ~] = local_sos_filter_sections(sos, X(iSignal, :), zi);
    Xf(iSignal, :) = ys .* g;
end

%% ===== PACKAGE FILTER INFO =====
% Info stores computational identity relevant to offline validation.
Info = struct();
Info.FilterType = 'iir_sos';
Info.Causality = 'causal';
Info.SOS = sos;
Info.G = g;
Info.Order = order;
Info.TargetBand = RTConfig.TargetBand;
Info.Fs = RTConfig.Fs;
Info.DiscardInitialSamples = local_discard_samples(RTConfig);
Info.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

end

function discard = local_discard_samples(RTConfig)
% Match the first-version discard convention used by nf_rt_filter_init.m.
if isfield(RTConfig, 'Filter') && isfield(RTConfig.Filter, 'DiscardInitialSamples') && ...
        ~isempty(RTConfig.Filter.DiscardInitialSamples)
    discard = RTConfig.Filter.DiscardInitialSamples;
else
    discard = max(RTConfig.Fs, RTConfig.PowerWindowSamples);
end
discard = max(0, ceil(discard));
end

function [y, zf] = local_sos_filter_sections(sos, x, zi)
% Apply second-order sections with explicit state handling.
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
