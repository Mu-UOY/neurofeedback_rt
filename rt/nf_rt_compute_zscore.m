function [Measure, RT] = nf_rt_compute_zscore(Measure, RT, RTConfig)
% NF_RT_COMPUTE_ZSCORE Compute raw, clipped, and smoothed z-score values.
%
% USAGE:  [Measure, RT] = nf_rt_compute_zscore(Measure, RT, RTConfig)
%
% DESCRIPTION:
%     Converts a valid power Measure into raw, clipped, and exponentially
%     smoothed z-scores when a finalized baseline is available, updating the
%     smoothing state in RT.

%% ===== SKIP WHEN Z-SCORE IS NOT AVAILABLE =====
% Invalid measures or missing baselines leave z-score fields unchanged.
if ~Measure.IsValid || ~isfield(RT, 'HasBaseline') || ~RT.HasBaseline
    return;
end

%% ===== READ BASELINE PARAMETERS =====
% Baseline mean/std may be stored under either current or legacy field names.
[mu, sigma] = local_get_baseline(RT);
if ~isfinite(sigma) || sigma <= 0
    Measure.InvalidReason = 'invalid_baseline_std';
    Measure.IsValid = false;
    return;
end
if ~isfinite(mu)
    Measure.InvalidReason = 'invalid_baseline_mean';
    Measure.IsValid = false;
    return;
end

%% ===== COMPUTE RAW AND CLIPPED Z =====
% Clipping bounds come from RTConfig.ZScore.
Measure.ZRaw = (Measure.Power - mu) ./ sigma;
clipRange = RTConfig.ZScore.ClipRange;
Measure.ZClipped = min(max(Measure.ZRaw, clipRange(1)), clipRange(2));

%% ===== UPDATE SMOOTHED Z =====
% First valid z-score initializes the smoothing state.
if ~RT.ZSmoothState.Initialized
    Measure.ZSmoothed = Measure.ZClipped;
    RT.ZSmoothState.Initialized = true;
else
    alpha = RT.ZSmoothState.Alpha;
    Measure.ZSmoothed = alpha .* RT.ZSmoothState.LastZSmoothed + ...
        (1 - alpha) .* Measure.ZClipped;
end

%% ===== STORE SMOOTHING STATE =====
% Persist the latest smoothed value for the next Measure.
RT.ZSmoothState.LastZSmoothed = Measure.ZSmoothed;
RT.ZSmoothState.LastUpdateSample = Measure.SampleIndex;

end

function [mu, sigma] = local_get_baseline(RT)
% Read baseline mean and standard deviation from supported field names.
mu = NaN;
sigma = NaN;

if ~isfield(RT, 'Baseline') || isempty(RT.Baseline)
    return;
end

if isfield(RT.Baseline, 'Mean')
    mu = RT.Baseline.Mean;
end
if isfield(RT.Baseline, 'Std')
    sigma = RT.Baseline.Std;
end
if (~isfinite(mu) || ~isfinite(sigma)) && isfield(RT.Baseline, 'PowerMean') && isfield(RT.Baseline, 'PowerStd')
    mu = RT.Baseline.PowerMean;
    sigma = RT.Baseline.PowerStd;
end
end
