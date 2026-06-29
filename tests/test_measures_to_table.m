function test_measures_to_table()
% TEST_MEASURES_TO_TABLE Check robust Measure table conversion.

%% ===== BUILD MINIMAL MEASURES =====
% Optional fields are intentionally absent so defaults are exercised.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.SessionMetadata.RunID = 'run_001';
RTConfig.SessionMetadata.DatasetName = 'synthetic';
RTConfig.SessionMetadata.SubjectID = 'subj_001';
RTConfig.SessionMetadata.SessionID = 'sess_001';
RTConfig.SessionMetadata.TrialID = 'trial_001';
RTConfig.SessionMetadata.StrategyLabel = 'strategy_a';
RTConfig.SessionMetadata.ConditionLabel = 'condition_a';

Measures = repmat(struct(), 1, 2);
for iMeasure = 1:2
    Measures(iMeasure).Power = iMeasure;
    Measures(iMeasure).ZRaw = iMeasure + 0.1;
    Measures(iMeasure).ZClipped = iMeasure + 0.2;
    Measures(iMeasure).ZSmoothed = iMeasure + 0.3;
    Measures(iMeasure).IsValid = true;
    Measures(iMeasure).SampleIndex = 100 .* iMeasure;
end

Baseline = struct();
Baseline.ConfigHash = 'BASE123';

%% ===== CONVERT TO TABLE =====
% Missing optional fields should be filled without errors.
T = nf_measures_to_table(Measures, RTConfig, Baseline);

assert(height(T) == numel(Measures), 'Measure table row count is wrong.');
required = {'RunID','DatasetName','SubjectID','SessionID','TrialID', ...
    'StrategyLabel','ConditionLabel','Power','ZRaw','ZClipped','ZSmoothed', ...
    'IsValid','SampleIndex','BaselineConfigHash'};
for iField = 1:numel(required)
    assert(ismember(required{iField}, T.Properties.VariableNames), ...
        'Missing measure table column: %s', required{iField});
end
assert(strcmp(T.RunID{1}, 'run_001'), 'RunID metadata was not preserved.');
assert(strcmp(T.DatasetName{1}, 'synthetic'), 'DatasetName metadata was not preserved.');
assert(strcmp(T.BaselineConfigHash{1}, 'BASE123'), 'BaselineConfigHash was not preserved.');
assert(all(T.IsValid), 'IsValid values were not preserved.');
assert(all(isnan(T.Time)), 'Missing numeric fields should become NaN.');
assert(all(strcmp(T.InvalidReason, '')), 'Missing text fields should become empty strings.');

%% ===== CHECK EMPTY INPUT =====
% Empty input should still expose the expected stable columns.
TEmpty = nf_measures_to_table([], RTConfig);
assert(height(TEmpty) == 0, 'Empty Measures input should return zero rows.');
assert(ismember('BaselineConfigHash', TEmpty.Properties.VariableNames), ...
    'Empty measure table is missing BaselineConfigHash.');

end
