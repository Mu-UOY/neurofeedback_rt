function test_fieldtrip_fileproxy_launcher_builds_expected_cfg()
% TEST_FIELDTRIP_FILEPROXY_LAUNCHER_BUILDS_EXPECTED_CFG Check producer cfg.

%% ===== BUILD REPLAY CONFIG WITH TEST HOOK =====
datasetPath = [tempname, '.mat'];
save(datasetPath, 'datasetPath');
cleanupObj = onCleanup(@() local_cleanup(datasetPath));
captured = struct();

[~, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath, [], ...
    'Port', 1973, 'Speed', 2, 'BlockSeconds', 0.25, ...
    'ReadEvents', false, 'Channel', {'MEG001','MEG002'}, ...
    'TestFileProxyFcn', @fake_fileproxy);

ReplayResult = nf_start_fieldtrip_file_replay(ReplayConfig);

assert(strcmp(ReplayResult.Status, 'completed'), 'Replay test hook did not complete.');
assert(strcmp(ReplayResult.TargetURI, 'buffer://localhost:1973'), 'Target URI mismatch.');
assert(strcmp(captured.dataset, datasetPath), 'cfg.dataset mismatch.');
assert(strcmp(captured.target.datafile, ReplayResult.TargetURI), 'cfg target mismatch.');
assert(captured.speed == 2, 'cfg.speed mismatch.');
assert(captured.blocksize == 0.25, 'cfg.blocksize mismatch.');
assert(isequal(captured.channel, {'MEG001','MEG002'}), 'cfg.channel mismatch.');
assert(strcmp(captured.readevent, 'no'), 'cfg.readevent mismatch.');

clear cleanupObj

    function fake_fileproxy(cfg)
        captured = cfg;
    end
end

function local_cleanup(pathValue)
if exist(pathValue, 'file') == 2
    delete(pathValue);
end
end
