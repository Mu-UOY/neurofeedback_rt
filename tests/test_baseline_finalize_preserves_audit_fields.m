function test_baseline_finalize_preserves_audit_fields()
% TEST_BASELINE_FINALIZE_PRESERVES_AUDIT_FIELDS Check baseline audit fields.

%% ===== BUILD BASELINE ACCUMULATOR =====
% Use percentile trimming so raw and usable values differ.
RTConfig = nf_default_config();
RTConfig.Baseline.OutlierMethod = 'percentile';
RTConfig.Baseline.OutlierPercentileLow = 0;
RTConfig.Baseline.OutlierPercentileHigh = 80;

values = [1 2 3 4 100];
BaselineAcc = nf_baseline_init(RTConfig);
BaselineAcc.Values = values;
BaselineAcc.ValidWindowCount = numel(values);

%% ===== REJECT OUTLIERS AND FINALIZE =====
% Finalization must preserve the audit trail produced by rejection.
BaselineAcc = nf_baseline_reject_outliers(BaselineAcc, RTConfig);
expectedRaw = BaselineAcc.RawValues;
expectedTrimmed = BaselineAcc.TrimmedValues;
expectedRejected = BaselineAcc.NTrimmedRejected;
expectedThresholds = BaselineAcc.OutlierThresholds;
Baseline = nf_baseline_finalize(BaselineAcc, RTConfig);

%% ===== CHECK AUDIT FIELDS =====
% Values are the full pre-trim trace; TrimmedValues are used for stats.
requiredFields = {'Values', 'RawValues', 'TrimmedValues', 'NTrimmedRejected', ...
    'OutlierMethod', 'OutlierThresholds'};
for iField = 1:numel(requiredFields)
    assert(isfield(Baseline, requiredFields{iField}), ...
        'Missing finalized baseline field: %s', requiredFields{iField});
end

assert(isequal(Baseline.Values, values), 'Baseline.Values did not preserve all valid powers.');
assert(isequal(Baseline.RawValues, expectedRaw), 'Baseline.RawValues was not preserved.');
assert(isequal(Baseline.TrimmedValues, expectedTrimmed), 'Baseline.TrimmedValues was not preserved.');
assert(Baseline.NTrimmedRejected == expectedRejected, 'NTrimmedRejected was not preserved.');
assert(strcmp(Baseline.OutlierMethod, 'percentile'), 'OutlierMethod was not preserved.');
assert(isequal(Baseline.OutlierThresholds, expectedThresholds), ...
    'OutlierThresholds was not preserved.');

assert(abs(Baseline.Mean - mean(expectedTrimmed)) < eps, ...
    'Baseline.Mean was not computed from TrimmedValues.');
assert(abs(Baseline.Std - std(expectedTrimmed)) < eps, ...
    'Baseline.Std was not computed from TrimmedValues.');

end
