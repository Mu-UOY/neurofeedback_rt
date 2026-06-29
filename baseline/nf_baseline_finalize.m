function Baseline = nf_baseline_finalize(BaselineAcc, RTConfig)
% NF_BASELINE_FINALIZE Convert an accumulator into a finalized baseline.
%
% USAGE:  Baseline = nf_baseline_finalize(BaselineAcc, RTConfig)
%
% DESCRIPTION:
%     Computes canonical Mean/Std from post-rejection usable powers, preserves
%     full and trimmed audit values, and copies provenance from the accumulator.

%% ===== SELECT USABLE VALUES =====
% TrimmedValues are the canonical usable set when available.
values = reshape(BaselineAcc.Values, 1, []);
rawValues = local_get_row_values(BaselineAcc, 'RawValues', values);
usableValues = local_get_row_values(BaselineAcc, 'TrimmedValues', values);
nTrimmedRejected = local_getfield_default(BaselineAcc, 'NTrimmedRejected', 0);
outlierMethod = local_get_outlier_method(BaselineAcc, RTConfig);
outlierThresholds = local_getfield_default(BaselineAcc, 'OutlierThresholds', struct());

%% ===== COMPUTE BASELINE STATS =====
% Use sample standard deviation when enough data exists.
if isempty(usableValues)
    mu = NaN;
elseif all(isfinite(usableValues))
    mu = mean(usableValues);
else
    mu = NaN;
end

if numel(usableValues) < 2 || any(~isfinite(usableValues))
    sigma = NaN;
else
    sigma = std(usableValues);
end

%% ===== BUILD FINAL BASELINE =====
% Mean and Std are canonical. PowerMean/PowerStd are readability aliases.
Baseline = struct();
Baseline.Type = 'baseline';
Baseline.Partial = false;
Baseline.Finalized = true;
Baseline.Mean = mu;
Baseline.Std = sigma;
Baseline.PowerMean = Baseline.Mean;
Baseline.PowerStd = Baseline.Std;
Baseline.Values = values;
Baseline.RawValues = rawValues;
Baseline.TrimmedValues = usableValues;
Baseline.NTrimmedRejected = nTrimmedRejected;
Baseline.OutlierMethod = outlierMethod;
Baseline.OutlierThresholds = outlierThresholds;
Baseline.ValidWindowCount = BaselineAcc.ValidWindowCount;
Baseline.UsableWindowCount = numel(usableValues);
Baseline.InvalidWindowCount = BaselineAcc.InvalidWindowCount;
Baseline.GapWindowCount = BaselineAcc.GapWindowCount;
Baseline.ArtifactWindowCount = BaselineAcc.ArtifactWindowCount;
Baseline.InvalidReasonCounts = BaselineAcc.InvalidReasonCounts;
Baseline.ConfigHash = BaselineAcc.ConfigHash;
Baseline.ConfigHashInputs = BaselineAcc.ConfigHashInputs;
Baseline.ConfigHashCreatedAt = BaselineAcc.ConfigHashCreatedAt;
Baseline.Metadata = BaselineAcc.Metadata;

%% ===== RECORD FINALIZATION METADATA =====
% FinalizedAt marks the creation of the saved baseline object.
Baseline.Metadata.FinalizedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Baseline.Metadata.TargetBand = RTConfig.TargetBand;
Baseline.Metadata.Fs = RTConfig.Fs;
Baseline.Metadata.ChunkSamples = RTConfig.ChunkSamples;
Baseline.Metadata.PowerWindowSamples = RTConfig.PowerWindowSamples;

end

function values = local_get_row_values(S, fieldName, defaultValue)
% Return row-vector audit values with a default.
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    values = reshape(S.(fieldName), 1, []);
else
    values = reshape(defaultValue, 1, []);
end
end

function method = local_get_outlier_method(BaselineAcc, RTConfig)
% Preserve accumulator method or fall back to the configured baseline method.
if isfield(BaselineAcc, 'OutlierMethod') && ~isempty(BaselineAcc.OutlierMethod)
    method = char(BaselineAcc.OutlierMethod);
elseif isfield(RTConfig, 'Baseline') && isfield(RTConfig.Baseline, 'OutlierMethod') && ...
        ~isempty(RTConfig.Baseline.OutlierMethod)
    method = char(RTConfig.Baseline.OutlierMethod);
else
    method = 'none';
end
end

function value = local_getfield_default(S, fieldName, defaultValue)
% Read a field with a fallback.
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    value = S.(fieldName);
else
    value = defaultValue;
end
end
