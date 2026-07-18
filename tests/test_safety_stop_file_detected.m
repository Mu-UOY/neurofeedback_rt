function test_safety_stop_file_detected()
% TEST_SAFETY_STOP_FILE_DETECTED Check configured stop-file detection.

%% ===== CREATE STOP FILE =====
Modes = nf_modes();
RTConfig = nf_live_config();
stopPath = [tempname, '.stop'];
fid = fopen(stopPath, 'w');
assert(fid > 0, 'Could not create temporary stop file.');
fprintf(fid, 'stop\n');
fclose(fid);
cleanupObj = onCleanup(@() local_cleanup(stopPath));

RTConfig.Safety.EnableStopFile = true;
RTConfig.Safety.StopFilePath = stopPath;
Safety = nf_safety_init_stop_flag(RTConfig, Modes.Session.LiveTrial);

[stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig);
assert(stopRequested, 'Stop file was not detected.');
assert(strcmp(Safety.StopReason, Modes.StopReason.StopFile), ...
    'Stop-file reason was not recorded.');

clear cleanupObj
end

function local_cleanup(pathValue)
if exist(pathValue, 'file') == 2
    delete(pathValue);
end
end
