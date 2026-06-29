function test_baseline_accumulation_and_finalization()
% TEST_BASELINE_ACCUMULATION_AND_FINALIZATION Check baseline math and audit fields.

%% ===== CONFIGURE BASELINE =====
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Baseline.MinValidWindows = 3;
RTConfig.Baseline.OutlierMethod = 'percentile';
RTConfig.Baseline.OutlierPercentileLow = 0;
RTConfig.Baseline.OutlierPercentileHigh = 80;

RT = nf_rt_init_schema();
RT.ConfigHash = 'TESTHASH';
RT.ConfigHashInputs.TargetBand = RTConfig.TargetBand;
BaselineAcc = nf_baseline_init(RTConfig, RT);

%% ===== ACCUMULATE MEASURES =====
% Invalid power should be excluded; valid outlier remains until trimming.
validPowers = [1 2 3 4 100];
for iPower = 1:numel(validPowers)
    Measure = nf_measure_empty();
    Measure.IsValid = true;
    Measure.Power = validPowers(iPower);
    BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig);
end

BadMeasure = nf_measure_empty();
BadMeasure.IsValid = false;
BadMeasure.Power = 999;
BadMeasure.InvalidReason = 'gap_in_window';
BadMeasure.GapInWindowFlag = true;
BaselineAcc = nf_baseline_update(BaselineAcc, BadMeasure, RTConfig);

%% ===== FINALIZE BASELINE =====
BaselineAcc = nf_baseline_reject_outliers(BaselineAcc, RTConfig);
Baseline = nf_baseline_finalize(BaselineAcc, RTConfig);
Quality = nf_baseline_check_quality(Baseline, RTConfig);

%% ===== CHECK ACCUMULATION AND TRIMMING =====
assert(isequal(Baseline.Values, validPowers), 'Baseline.Values did not preserve all valid powers.');
assert(~any(Baseline.Values == 999), 'Invalid power entered Baseline.Values.');
assert(isequal(Baseline.TrimmedValues, [1 2 3 4]), 'Unexpected TrimmedValues after percentile rejection.');
assert(BaselineAcc.NTrimmedRejected == 1, 'Expected one rejected outlier.');

expectedMean = mean([1 2 3 4]);
expectedStd = std([1 2 3 4]);
assert(abs(Baseline.Mean - expectedMean) < 1e-12, 'Baseline.Mean mismatch.');
assert(abs(Baseline.Std - expectedStd) < 1e-12, 'Baseline.Std mismatch.');
assert(Baseline.PowerMean == Baseline.Mean, 'PowerMean alias diverged from Mean.');
assert(Baseline.PowerStd == Baseline.Std, 'PowerStd alias diverged from Std.');
assert(Baseline.ValidWindowCount == 5, 'Unexpected valid window count.');
assert(Baseline.InvalidWindowCount == 1, 'Unexpected invalid window count.');
assert(Baseline.GapWindowCount == 1, 'Unexpected gap window count.');
assert(Quality.Pass, 'Baseline quality should pass.');

end
