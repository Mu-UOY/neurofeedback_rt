function test_live_rt_dry_run_no_baseline_zscore_by_default()
% TEST_LIVE_RT_DRY_RUN_NO_BASELINE_ZSCORE_BY_DEFAULT Check dry-run normalization.

[RTConfig, tempRoot] = nf_test_live_rt_dry_run_config(35);
cleanupObj = onCleanup(@() local_cleanup(tempRoot));
Result = nf_run_live_rt_dry_run(RTConfig);
loaded = load(Result.ReportMatPath, 'RT', 'Measures');
RT = loaded.RT;
Measures = loaded.Measures;

assert(Result.NoBaselinePass == true, 'NoBaselinePass was false.');
assert(Result.RTHasBaseline == false, 'Result reported a baseline.');
assert(isfield(RT, 'HasBaseline') && RT.HasBaseline == false, 'Saved RT reported a baseline.');
assert(all(arrayfun(@(m) isnan(m.ZRaw), Measures)), 'ZRaw should remain NaN.');
assert(all(arrayfun(@(m) isnan(m.ZClipped), Measures)), 'ZClipped should remain NaN.');
assert(all(arrayfun(@(m) isnan(m.ZSmoothed), Measures)), 'ZSmoothed should remain NaN.');

rootDir = fileparts(fileparts(mfilename('fullpath')));
txt = fileread(fullfile(rootDir, 'main', 'nf_run_live_rt_dry_run.m'));
forbidden = {'nf_load_baseline','nf_baseline_init','nf_baseline_update','nf_baseline_finalize'};
for iName = 1:numel(forbidden)
    assert(~contains(txt, forbidden{iName}), 'Runner contains forbidden baseline function: %s', forbidden{iName});
end

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
