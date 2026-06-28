function [chunk, RT] = nf_rt_filter_apply(chunk, RT, RTConfig) %#ok<INUSD>
% NF_RT_FILTER_APPLY Apply the streaming filter to one post-spatial chunk.
%
% USAGE:  [chunk, RT] = nf_rt_filter_apply(chunk, RT, RTConfig)
%
% DESCRIPTION:
%     Applies the prepared streaming filter to one projected chunk, carries
%     filter state across chunks, updates warmup counters, and writes the
%     filtered data back to the chunk.

%% ===== CHECK SIGNAL COUNT =====
% The filter was initialized for the projected signal count.
X = chunk.Data;
NSignals = size(X, 1);

if NSignals ~= RT.Filter.NSignals
    error('Filter expected %d signals, received %d.', RT.Filter.NSignals, NSignals);
end

%% ===== APPLY FILTER =====
% Filter state is stored inside RT.Filter and updated in place.
switch RT.Filter.Type
    case 'none'
        % Passthrough mode leaves data unchanged.
        Y = X;

    case 'brainstorm_fir'
        % Standard causal FIR/IIR filtering with one state vector per signal.
        Y = zeros(size(X));
        for iSignal = 1:NSignals
            [Y(iSignal, :), RT.Filter.zi(:, iSignal)] = filter( ...
                RT.Filter.b, RT.Filter.a, X(iSignal, :), RT.Filter.zi(:, iSignal));
        end

    case 'iir_sos'
        % Apply SOS sections per signal and apply the scalar gain afterward.
        Y = zeros(size(X));
        if ~isscalar(RT.Filter.G)
            error('RT.Filter.G must be scalar in the first-version SOS implementation.');
        end
        for iSignal = 1:NSignals
            [ys, RT.Filter.zi(:, :, iSignal)] = local_sos_filter_sections( ...
                RT.Filter.SOS, X(iSignal, :), RT.Filter.zi(:, :, iSignal));
            Y(iSignal, :) = ys .* RT.Filter.G;
        end

    otherwise
        error('Unknown filter type: %s', RT.Filter.Type);
end

%% ===== UPDATE CHUNK AND FILTER STATE =====
% SamplesProcessed drives the filter warmup gate used by power estimation.
chunk.Data = Y;
RT.Filter.SamplesProcessed = RT.Filter.SamplesProcessed + chunk.NSamples;
RT.Filter.WarmupComplete = RT.Filter.SamplesProcessed >= RT.Filter.DiscardInitialSamples;

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
