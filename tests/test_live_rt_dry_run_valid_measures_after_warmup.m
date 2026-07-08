function test_live_rt_dry_run_valid_measures_after_warmup()
% TEST_LIVE_RT_DRY_RUN_VALID_MEASURES_AFTER_WARMUP Check valid power appears.

[RTConfig, tempRoot] = nf_test_live_rt_dry_run_config(35);
cleanupObj = onCleanup(@() local_cleanup(tempRoot));
Result = nf_run_live_rt_dry_run(RTConfig);
loaded = load(Result.ReportMatPath, 'Measures');
Measures = loaded.Measures;

assert(Result.NValidMeasures >= 1, 'No valid measures were reported.');
assert(Result.FirstValidMeasureChunk >= 10, 'Valid measure appeared before expected warmup/window fill.');
isValid = arrayfun(@(m) m.IsValid && isfinite(m.Power), Measures);
assert(any(isValid), 'No finite valid power measure found.');

validMeasures = Measures(isValid);
for iMeasure = 1:numel(validMeasures)
    if isfinite(validMeasures(iMeasure).WindowStartSample) && ...
            isfinite(validMeasures(iMeasure).WindowEndSample)
        nWindow = validMeasures(iMeasure).WindowEndSample - ...
            validMeasures(iMeasure).WindowStartSample + 1;
        assert(nWindow == 4800, 'Valid Measure used unexpected window length.');
    end
end

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
