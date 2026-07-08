function test_make_session_output_dir_unique()
% TEST_MAKE_SESSION_OUTPUT_DIR_UNIQUE Check live session folder creation.

%% ===== CREATE ISOLATED SESSION FOLDERS =====
% Tests must not write to the repository outputs/live folder.
[RTConfig, cleanupObj] = local_temp_config(); %#ok<ASGLU>

S1 = nf_make_session_output_dir(RTConfig, 'mock live test');
S2 = nf_make_session_output_dir(RTConfig, 'mock live test');

assert(exist(S1.SessionDir, 'dir') == 7, 'First session dir was not created.');
assert(exist(S2.SessionDir, 'dir') == 7, 'Second session dir was not created.');
assert(~strcmp(S1.SessionDir, S2.SessionDir), ...
    'Session output directories were not collision-safe.');
assert(strcmp(S1.Label, 'mock_live_test'), 'Session label was not sanitized.');
assert(S1.IsPartial == true, 'New session should be partial.');
assert(S1.Finalized == false, 'New session should not be finalized.');

requiredDirs = {'ConfigDir','SourceDir','BaselineDir','TrialDir','LogsDir', ...
    'TracesDir','ReportsDir','DebugChunksDir'};
for iDir = 1:numel(requiredDirs)
    assert(exist(S1.(requiredDirs{iDir}), 'dir') == 7, ...
        'Missing session subdirectory: %s', requiredDirs{iDir});
end

end

function [RTConfig, cleanupObj] = local_temp_config()
tempProjectRoot = tempname();
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() local_rmdir(tempProjectRoot));
RTConfig = nf_mock_live_test_config();
RTConfig.Debug.Verbose = false;
RTConfig.Paths.ProjectRoot = tempProjectRoot;
end

function local_rmdir(pathToRemove)
if exist(pathToRemove, 'dir')
    rmdir(pathToRemove, 's');
end
end
