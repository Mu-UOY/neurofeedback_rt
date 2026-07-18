function test_validation_to_table()
% TEST_VALIDATION_TO_TABLE Check robust validation Results table conversion.

%% ===== BUILD MINIMAL RESULTS =====
% Include current nested fields and leave unrelated optional fields absent.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.SessionMetadata.RunID = 'run_003';
RTConfig.SessionMetadata.DatasetName = 'validation_dataset';
RTConfig.Source.Mode = 'simulated_online';
RTConfig.Filter.EmpiricalDelaySamples = 4;
RTConfig.Filter.AnalyticGroupDelaySamples = 2;
RTConfig.Filter.DelayCorrectionUsed = 4;

Results = struct();
Results.Compare.Correlation = 0.99;
Results.Compare.RMSE = 0.01;
Results.Runtime.Status = 'PASS';
Results.DroppedChunks.Status = 'PASS';
Results.Step1.BandDetection.Status = 'PASS';
Results.Step1.BandDetection.PeakFrequency = 6;
Results.Step1.BandDetection.PeakInsideTargetBand = true;
Results.NChunks = 5;
Results.NValidMeasures = 4;
Results.ConfigHash = 'VAL123';

%% ===== CONVERT TO TABLE =====
% Missing optional fields should be filled without errors.
T = nf_validation_to_table(Results, RTConfig);

assert(height(T) == 1, 'Validation table should have one row.');
required = {'RunID','DatasetName','SourceMode','Correlation','RMSE', ...
    'EmpiricalDelaySamples','AnalyticGroupDelaySamples','DelayCorrectionUsed', ...
    'RuntimeStatus','DroppedChunkStatus','BandDetectionStatus', ...
    'PeakFrequency','PeakInsideTargetBand','NChunks','NValidMeasures', ...
    'ConfigHash','Pass'};
for iField = 1:numel(required)
    assert(ismember(required{iField}, T.Properties.VariableNames), ...
        'Missing validation table column: %s', required{iField});
end

assert(abs(T.Correlation - 0.99) < eps, 'Correlation was not preserved.');
assert(abs(T.RMSE - 0.01) < eps, 'RMSE was not preserved.');
assert(strcmp(T.RuntimeStatus{1}, 'PASS'), 'RuntimeStatus was not preserved.');
assert(T.PeakInsideTargetBand == true, 'PeakInsideTargetBand was not preserved.');
assert(T.Pass == true, 'Pass was not inferred from PASS statuses.');

%% ===== CHECK FLAT FIELD FALLBACK =====
% Flat Results structs should also convert safely.
FlatResults = struct();
FlatResults.Correlation = 0.5;
FlatResults.RMSE = 2;
FlatResults.Status = 'FAIL';
TFlat = nf_validation_to_table(FlatResults, RTConfig);
assert(abs(TFlat.Correlation - 0.5) < eps, 'Flat Correlation was not preserved.');
assert(TFlat.Pass == false, 'Flat FAIL status should not pass.');

%% ===== CHECK EMPTY INPUT =====
% Empty input should still expose the expected stable columns.
TEmpty = nf_validation_to_table([], RTConfig);
assert(height(TEmpty) == 0, 'Empty Results input should return zero rows.');
assert(ismember('Pass', TEmpty.Properties.VariableNames), ...
    'Empty validation table is missing Pass.');

end
