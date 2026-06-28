function [Power, PowerPerSignal, IsValid, Diagnostics] = nf_rt_compute_power(window, RT, RTConfig)
% NF_RT_COMPUTE_POWER Compute sliding-window band-limited power.
%
% USAGE:  [Power, PowerPerSignal, IsValid, Diagnostics] = nf_rt_compute_power(window, RT, RTConfig)
%
% DESCRIPTION:
%     Validates a buffered window, rejects incomplete, discontinuous, warmup,
%     or nonfinite windows, then computes mean squared power per signal and
%     across signals.

%% ===== INITIALIZE OUTPUTS =====
% Invalid-by-default outputs make early returns explicit.
Power = NaN;
if isfield(window, 'Data') && ~isempty(window.Data)
    PowerPerSignal = NaN(size(window.Data, 1), 1);
else
    PowerPerSignal = [];
end
IsValid = false;

%% ===== INITIALIZE DIAGNOSTICS =====
% Diagnostics explains why a window is invalid.
Diagnostics = struct();
Diagnostics.InvalidReason = '';
Diagnostics.GapInWindowFlag = false;
Diagnostics.DroppedChunkFlag = false;
Diagnostics.WindowNSamples = 0;
Diagnostics.FilterWarmupComplete = false;

%% ===== CHECK WINDOW STRUCT =====
% Empty windows occur before the buffer has enough samples.
if isempty(window) || ~isfield(window, 'NSamples')
    Diagnostics.InvalidReason = 'empty_window';
    return;
end

%% ===== RECORD WINDOW STATUS =====
% These diagnostics are useful even when the window is later rejected.
Diagnostics.WindowNSamples = window.NSamples;
Diagnostics.DroppedChunkFlag = isfield(window, 'ContainsDropped') && window.ContainsDropped;
Diagnostics.FilterWarmupComplete = RT.Filter.WarmupComplete;

%% ===== REQUIRE FULL POWER WINDOW =====
% The buffer must contain the configured number of samples.
if window.NSamples < RTConfig.PowerWindowSamples
    Diagnostics.InvalidReason = 'buffer_not_full';
    return;
end

%% ===== REJECT GAPPED WINDOWS =====
% Discontinuous data should not contribute to target-band power.
Diagnostics.GapInWindowFlag = nf_buffer_window_has_gap(window, RTConfig);
if Diagnostics.GapInWindowFlag
    Diagnostics.InvalidReason = 'gap_in_window';
    return;
end

%% ===== REJECT FILTER WARMUP =====
% Early filtered samples are excluded until the configured discard period passes.
if ~RT.Filter.WarmupComplete || window.SampleIndex(1) <= RT.Filter.DiscardInitialSamples
    Diagnostics.InvalidReason = 'filter_warmup';
    return;
end

%% ===== REJECT NONFINITE DATA =====
% NaN or Inf values would make power unreliable.
if any(~isfinite(window.Data(:)))
    Diagnostics.InvalidReason = 'nonfinite_window';
    return;
end

%% ===== COMPUTE POWER =====
% Power is mean squared amplitude per signal, averaged across signals.
PowerPerSignal = mean(window.Data .^ 2, 2);
Power = mean(PowerPerSignal);
IsValid = isfinite(Power);

% Preserve the invalid reason if the final scalar power is not finite.
if ~IsValid
    Diagnostics.InvalidReason = 'nonfinite_power';
end

end
