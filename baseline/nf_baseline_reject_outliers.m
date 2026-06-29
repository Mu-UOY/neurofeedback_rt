function BaselineAcc = nf_baseline_reject_outliers(BaselineAcc, RTConfig)
% NF_BASELINE_REJECT_OUTLIERS Trim baseline powers without altering originals.
%
% USAGE:  BaselineAcc = nf_baseline_reject_outliers(BaselineAcc, RTConfig)
%
% DESCRIPTION:
%     Recomputes RawValues and TrimmedValues from BaselineAcc.Values using the
%     configured outlier method. BaselineAcc.Values always remains the full
%     valid pre-trim audit trace.

%% ===== COPY RAW VALUES =====
% Recompute from current Values on every call.
values = reshape(BaselineAcc.Values, 1, []);
BaselineAcc.RawValues = values;
BaselineAcc.TrimmedValues = values;
BaselineAcc.NTrimmedRejected = 0;

method = 'percentile';
if isfield(RTConfig, 'Baseline') && isfield(RTConfig.Baseline, 'OutlierMethod')
    method = lower(char(RTConfig.Baseline.OutlierMethod));
end

%% ===== HANDLE SMALL BASELINES =====
% Trimming tiny samples is unstable; preserve all valid values.
if numel(values) < 3
    BaselineAcc.OutlierMethod = method;
    BaselineAcc.OutlierThresholds = local_thresholds(RTConfig, NaN, NaN);
    return;
end

%% ===== APPLY OUTLIER METHOD =====
% Each branch selects usable values but never changes Values.
switch method
    case 'none'
        keep = true(size(values));
        low = NaN;
        high = NaN;

    case 'percentile'
        lowPct = RTConfig.Baseline.OutlierPercentileLow;
        highPct = RTConfig.Baseline.OutlierPercentileHigh;
        low = local_percentile(values, lowPct);
        high = local_percentile(values, highPct);
        keep = values >= low & values <= high;

    case 'zscore'
        mu = mean(values);
        sigma = std(values);
        threshold = RTConfig.Baseline.OutlierZThreshold;
        low = -threshold;
        high = threshold;
        if ~isfinite(sigma) || sigma <= 0
            keep = true(size(values));
        else
            z = (values - mu) ./ sigma;
            keep = abs(z) <= threshold;
        end

    otherwise
        error('Unknown baseline outlier method: %s', method);
end

% If trimming would remove everything, keep all valid values.
if ~any(keep)
    keep = true(size(values));
end

BaselineAcc.TrimmedValues = values(keep);
BaselineAcc.NTrimmedRejected = numel(values) - nnz(keep);
BaselineAcc.OutlierMethod = method;
BaselineAcc.OutlierThresholds = local_thresholds(RTConfig, low, high);

end

function q = local_percentile(values, pct)
% Compute percentile by sorted linear interpolation without Statistics Toolbox.
values = sort(values(:)');
n = numel(values);
if n == 1
    q = values;
    return;
end

pos = 1 + (pct ./ 100) .* (n - 1);
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    q = values(lo);
else
    w = pos - lo;
    q = (1 - w) .* values(lo) + w .* values(hi);
end
end

function thresholds = local_thresholds(RTConfig, low, high)
% Store outlier settings and computed thresholds for auditability.
thresholds = struct();
thresholds.PercentileLow = RTConfig.Baseline.OutlierPercentileLow;
thresholds.PercentileHigh = RTConfig.Baseline.OutlierPercentileHigh;
thresholds.ZThreshold = RTConfig.Baseline.OutlierZThreshold;
thresholds.LowValue = low;
thresholds.HighValue = high;
end
