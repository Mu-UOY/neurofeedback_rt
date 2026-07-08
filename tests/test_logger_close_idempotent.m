function test_logger_close_idempotent()
% TEST_LOGGER_CLOSE_IDEMPOTENT Check double-close behavior.

%% ===== CLOSE TWICE =====
% A second close should not duplicate final files or change the final path.
[RTConfig, cleanupObj] = local_temp_config(); %#ok<ASGLU>
Logger = nf_logger_init(RTConfig, 'mock_live_test', struct());
Logger = nf_logger_append_measure(Logger, nf_measure_empty());

Logger = nf_logger_close(Logger);
firstFinalPath = Logger.FinalLogPath;
Logger = nf_logger_close(Logger);

assert(Logger.Closed == true, 'Logger should remain closed.');
assert(strcmp(Logger.FinalLogPath, firstFinalPath), ...
    'Double-close changed FinalLogPath.');
assert(exist(firstFinalPath, 'file') == 2, 'Final log missing after double-close.');

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
