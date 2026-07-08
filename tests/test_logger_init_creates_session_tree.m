function test_logger_init_creates_session_tree()
% TEST_LOGGER_INIT_CREATES_SESSION_TREE Check logger initialization outputs.

%% ===== INITIALIZE LOGGER =====
% Config and source metadata should be saved once at init.
[RTConfig, cleanupObj] = local_temp_config(); %#ok<ASGLU>

Source = struct();
Source.Mode = RTConfig.Source.Mode;
Source.Fs = RTConfig.Fs;
Source.NChannels = 2;
Source.ChannelNames = {'C1','C2'};
Source.ChannelNamesAfterCorrection = {'C1','C2'};

Logger = nf_logger_init(RTConfig, 'mock_live_test', Source);

assert(exist(Logger.Session.SessionDir, 'dir') == 7, 'Session dir missing.');
assert(exist(Logger.Session.LogsDir, 'dir') == 7, 'Logs dir missing.');
assert(exist(Logger.ConfigPath, 'file') == 2, 'RTConfig MAT was not saved.');
assert(exist(Logger.SourcePath, 'file') == 2, 'SourceSummary MAT was not saved.');
assert(Logger.NChunks == 0, 'Logger should start with zero chunks.');
assert(Logger.NMeasures == 0, 'Logger should start with zero Measures.');
assert(Logger.Partial == true, 'Logger should start partial.');
assert(Logger.Finalized == false, 'Logger should not start finalized.');
assert(Logger.Closed == false, 'Logger should not start closed.');
assert(Logger.LastPartialSavedChunkIndex == 0, 'Unexpected partial chunk index.');
assert(Logger.LastPartialSavedMeasureIndex == 0, 'Unexpected partial measure index.');
assert(strcmp(Logger.SourceSummary.Mode, RTConfig.Source.Mode), ...
    'SourceSummary.Mode was not preserved.');
assert(Logger.SourceSummary.NChannels == 2, 'SourceSummary.NChannels mismatch.');

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
