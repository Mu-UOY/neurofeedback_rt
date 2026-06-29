function Quality = nf_baseline_check_quality(Baseline, RTConfig)
% NF_BASELINE_CHECK_QUALITY Validate a finalized baseline for trial use.
%
% USAGE:  Quality = nf_baseline_check_quality(Baseline, RTConfig)
%
% DESCRIPTION:
%     Confirms canonical baseline fields are finalized, finite, nondegenerate,
%     and based on enough valid and usable windows.

%% ===== INITIALIZE QUALITY =====
% Fail closed until every check passes.
Quality = struct();
Quality.Pass = false;
Quality.Status = 'FAIL';
Quality.Message = '';
Quality.NValid = NaN;
Quality.NUsable = NaN;
Quality.Mean = NaN;
Quality.Std = NaN;

%% ===== CHECK BASELINE IDENTITY =====
% Trial runs only accept finalized baseline structs.
if ~isstruct(Baseline)
    Quality.Message = 'Baseline must be a struct.';
    return;
end
if ~isfield(Baseline, 'Type') || ~strcmp(Baseline.Type, 'baseline')
    Quality.Message = 'Baseline.Type must be baseline.';
    return;
end
if ~isfield(Baseline, 'Partial') || Baseline.Partial
    Quality.Message = 'Baseline must not be partial.';
    return;
end
if ~isfield(Baseline, 'Finalized') || ~Baseline.Finalized
    Quality.Message = 'Baseline must be finalized.';
    return;
end

%% ===== READ COUNTS AND STATS =====
% Usable count may need to be inferred for older saved baselines.
Quality.NValid = local_getfield_default(Baseline, 'ValidWindowCount', numel(local_values(Baseline)));
Quality.NUsable = local_usable_count(Baseline);
Quality.Mean = local_getfield_default(Baseline, 'Mean', NaN);
Quality.Std = local_getfield_default(Baseline, 'Std', NaN);
minValid = RTConfig.Baseline.MinValidWindows;

%% ===== CHECK NUMERIC QUALITY =====
% Mean/std and enough windows are required for stable z-scoring.
if ~isfinite(Quality.Mean)
    Quality.Message = 'Baseline.Mean must be finite.';
    return;
end
if ~isfinite(Quality.Std) || Quality.Std <= 0
    Quality.Message = 'Baseline.Std must be finite and > 0.';
    return;
end
if Quality.NValid < minValid
    Quality.Message = sprintf('Baseline has %d valid windows; required %d.', Quality.NValid, minValid);
    return;
end
if Quality.NUsable < minValid
    Quality.Message = sprintf('Baseline has %d usable windows; required %d.', Quality.NUsable, minValid);
    return;
end

%% ===== PASS QUALITY =====
Quality.Pass = true;
Quality.Status = 'PASS';
Quality.Message = 'Baseline quality passed.';

end

function n = local_usable_count(Baseline)
% Infer usable count from canonical fields when needed.
if isfield(Baseline, 'UsableWindowCount') && ~isempty(Baseline.UsableWindowCount)
    n = Baseline.UsableWindowCount;
elseif isfield(Baseline, 'TrimmedValues') && ~isempty(Baseline.TrimmedValues)
    n = numel(Baseline.TrimmedValues);
else
    n = numel(local_values(Baseline));
end
end

function values = local_values(Baseline)
% Return all valid baseline values when present.
if isfield(Baseline, 'Values')
    values = Baseline.Values;
else
    values = [];
end
end

function value = local_getfield_default(S, fieldName, defaultValue)
% Read a field with a fallback.
if isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
