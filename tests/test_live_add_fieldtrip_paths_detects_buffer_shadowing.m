function test_live_add_fieldtrip_paths_detects_buffer_shadowing()
% TEST_LIVE_ADD_FIELDTRIP_PATHS_DETECTS_BUFFER_SHADOWING Check integration.

%% ===== BUILD FAKE BUFFER OUTSIDE REQUIRED ROOT =====
oldPath = path;
tmpRoot = tempname;
mkdir(tmpRoot);
cleanupObj = onCleanup(@() local_cleanup(oldPath, tmpRoot)); %#ok<NASGU>

bufferFolder = fullfile(tmpRoot, 'fake_buffer');
mkdir(bufferFolder);
bufferPath = fullfile(bufferFolder, 'buffer.m');
local_write_fake_buffer(bufferPath);

RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.Host = 'configured-host';
RTConfig.Source.FieldTrip.Port = 1;
RTConfig.Source.FieldTrip.SettingOrigin.Host = 'config';
RTConfig.Source.FieldTrip.SettingOrigin.Port = 'config';
RTConfig.Source.FieldTrip.BufferMPath = bufferPath;
RTConfig.Source.FieldTrip.RequiredBufferRoot = fullfile(tmpRoot, 'required_root');

didError = false;
try
    nf_live_add_fieldtrip_paths(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'RequiredBufferRoot'), ...
        'Unexpected shadowing integration error: %s', ME.message);
end
assert(didError, 'RequiredBufferRoot mismatch did not fail path setup.');

end

function local_write_fake_buffer(bufferPath)
% Create a minimal fake buffer.m for path resolution.
fid = fopen(bufferPath, 'w');
fprintf(fid, 'function varargout = buffer(varargin)\n');
fprintf(fid, 'varargout = cell(1, nargout);\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function local_cleanup(oldPath, tmpRoot)
% Restore MATLAB path and remove temp tree.
path(oldPath);
if exist(tmpRoot, 'dir') == 7
    rmdir(tmpRoot, 's');
end
end
