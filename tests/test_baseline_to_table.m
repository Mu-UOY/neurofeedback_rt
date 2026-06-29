function test_baseline_to_table()
% TEST_BASELINE_TO_TABLE Check robust baseline table conversion.

%% ===== BUILD MINIMAL BASELINE =====
% Mean/Std are canonical; PowerMean/PowerStd aliases are filled when absent.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.SessionMetadata.RunID = 'run_002';
RTConfig.SessionMetadata.DatasetName = 'baseline_dataset';

Baseline = struct();
Baseline.Type = 'baseline';
Baseline.Partial = false;
Baseline.Finalized = true;
Baseline.Mean = 10;
Baseline.Std = 2;
Baseline.ValidWindowCount = 12;
Baseline.UsableWindowCount = 11;
Baseline.InvalidWindowCount = 3;
Baseline.GapWindowCount = 1;
Baseline.ArtifactWindowCount = 2;
Baseline.NTrimmedRejected = 1;
Baseline.OutlierMethod = 'percentile';
Baseline.OutlierThresholds.LowValue = 1;
Baseline.OutlierThresholds.HighValue = 20;
Baseline.Quality.Pass = true;
Baseline.Quality.Status = 'PASS';
Baseline.Quality.Message = 'ok';
Baseline.ConfigHash = 'HASH123';
Baseline.ConfigHashCreatedAt = '2026-06-28 12:00:00';

%% ===== CONVERT TO TABLE =====
% Missing aliases should be filled from canonical Mean/Std.
T = nf_baseline_to_table(Baseline, RTConfig);

assert(height(T) == 1, 'Baseline table should have one row.');
required = {'RunID','DatasetName','Mean','Std','PowerMean','PowerStd', ...
    'ValidWindowCount','UsableWindowCount','InvalidWindowCount', ...
    'GapWindowCount','ArtifactWindowCount','NTrimmedRejected', ...
    'OutlierMethod','OutlierThresholdLow','OutlierThresholdHigh', ...
    'QualityPass','QualityStatus','QualityMessage','ConfigHash'};
for iField = 1:numel(required)
    assert(ismember(required{iField}, T.Properties.VariableNames), ...
        'Missing baseline table column: %s', required{iField});
end

assert(T.Mean == 10 && T.Std == 2, 'Canonical Mean/Std were not preserved.');
assert(T.PowerMean == 10 && T.PowerStd == 2, 'PowerMean/PowerStd aliases were not filled.');
assert(T.ValidWindowCount == 12, 'ValidWindowCount was not preserved.');
assert(strcmp(T.ConfigHash{1}, 'HASH123'), 'ConfigHash was not preserved.');
assert(T.QualityPass == true, 'QualityPass was not preserved.');

%% ===== CHECK ALIAS FALLBACK =====
% Canonical fields can fall back to aliases for older baseline structs.
AliasBaseline = rmfield(Baseline, {'Mean','Std'});
AliasBaseline.PowerMean = 5;
AliasBaseline.PowerStd = 1;
TAlias = nf_baseline_to_table(AliasBaseline, RTConfig);
assert(TAlias.Mean == 5 && TAlias.Std == 1, ...
    'Canonical Mean/Std were not filled from aliases.');

%% ===== CHECK EMPTY INPUT =====
% Empty input should still expose the expected stable columns.
TEmpty = nf_baseline_to_table([], RTConfig);
assert(height(TEmpty) == 0, 'Empty Baseline input should return zero rows.');
assert(ismember('ConfigHash', TEmpty.Properties.VariableNames), ...
    'Empty baseline table is missing ConfigHash.');

end
