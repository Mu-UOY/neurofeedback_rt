function test_baseline_quality_rejects_poor_baseline()
% TEST_BASELINE_QUALITY_REJECTS_POOR_BASELINE Check baseline quality failures.

%% ===== CONFIGURE QUALITY CHECK =====
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Baseline.MinValidWindows = 3;

%% ===== TOO FEW VALID WINDOWS =====
Baseline = local_baseline([1 2], [1 2], 2, 2);
Quality = nf_baseline_check_quality(Baseline, RTConfig);
assert(~Quality.Pass, 'Too few valid windows should fail.');

%% ===== TOO FEW USABLE WINDOWS =====
Baseline = local_baseline([1 2 3 4], [1 2], 4, 2);
Quality = nf_baseline_check_quality(Baseline, RTConfig);
assert(~Quality.Pass, 'Too few usable windows should fail.');

%% ===== ZERO OR NAN STANDARD DEVIATION =====
Baseline = local_baseline([1 1 1], [1 1 1], 3, 3);
Quality = nf_baseline_check_quality(Baseline, RTConfig);
assert(~Quality.Pass, 'Zero standard deviation should fail.');

Baseline = local_baseline([1 2 3], [1 2 3], 3, 3);
Baseline.Std = NaN;
Baseline.PowerStd = NaN;
Quality = nf_baseline_check_quality(Baseline, RTConfig);
assert(~Quality.Pass, 'NaN standard deviation should fail.');

%% ===== PARTIAL, UNFINALIZED, AND WRONG TYPE =====
Baseline = local_baseline([1 2 3], [1 2 3], 3, 3);
Baseline.Partial = true;
Quality = nf_baseline_check_quality(Baseline, RTConfig);
assert(~Quality.Pass, 'Partial baseline should fail.');

Baseline = local_baseline([1 2 3], [1 2 3], 3, 3);
Baseline.Finalized = false;
Quality = nf_baseline_check_quality(Baseline, RTConfig);
assert(~Quality.Pass, 'Unfinalized baseline should fail.');

Baseline = local_baseline([1 2 3], [1 2 3], 3, 3);
Baseline.Type = 'baseline_accumulator';
Quality = nf_baseline_check_quality(Baseline, RTConfig);
assert(~Quality.Pass, 'Wrong baseline Type should fail.');

end

function Baseline = local_baseline(values, trimmedValues, nValid, nUsable)
Baseline = struct();
Baseline.Type = 'baseline';
Baseline.Partial = false;
Baseline.Finalized = true;
Baseline.Values = values;
Baseline.TrimmedValues = trimmedValues;
Baseline.ValidWindowCount = nValid;
Baseline.UsableWindowCount = nUsable;
Baseline.InvalidWindowCount = 0;
Baseline.GapWindowCount = 0;
Baseline.ArtifactWindowCount = 0;
Baseline.InvalidReasonCounts = struct();
Baseline.Mean = mean(trimmedValues);
Baseline.Std = std(trimmedValues);
Baseline.PowerMean = Baseline.Mean;
Baseline.PowerStd = Baseline.Std;
Baseline.ConfigHash = '';
Baseline.ConfigHashInputs = struct();
Baseline.Metadata = struct();
end
