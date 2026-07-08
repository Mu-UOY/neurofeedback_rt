function test_live_rt_dry_run_fake_buffer_technical_fallback_passes()
% TEST_LIVE_RT_DRY_RUN_FAKE_BUFFER_TECHNICAL_FALLBACK_PASSES Run Step 3C at home.

[RTConfig, tempRoot] = nf_test_live_rt_dry_run_config(35);
cleanupObj = onCleanup(@() local_cleanup(tempRoot));

Result = nf_run_live_rt_dry_run(RTConfig);

assert(Result.Pass == true, 'Live RT dry run did not pass: %s', Result.Message);
assert(Result.NProcessedChunks == RTConfig.LiveRTDryRun.NChunks, 'Unexpected processed chunk count.');
assert(Result.RTPrepared == true, 'RT was not prepared.');
assert(Result.FilterStateUpdatedPass == true, 'Filter state did not advance.');
assert(Result.BufferFilledPass == true, 'Buffer did not fill.');
assert(Result.ValidMeasureAppearedPass == true, 'No valid measure appeared.');
assert(Result.PowerWindowLengthPass == true, 'Power window length check failed.');
assert(Result.FeedbackUnmappedPass == true, 'Feedback fields were mapped.');
assert(Result.NoBaselinePass == true, 'Dry run unexpectedly had a baseline.');
assert(exist(Result.ReportMatPath, 'file') == 2, 'MAT report missing.');
assert(exist(Result.ReportTextPath, 'file') == 2, 'TXT report missing.');
assert(exist(Result.MeasureCsvPath, 'file') == 2, 'Measure CSV missing.');
assert(exist(Result.ChunkMetaCsvPath, 'file') == 2, 'Chunk metadata CSV missing.');

clear cleanupObj
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
