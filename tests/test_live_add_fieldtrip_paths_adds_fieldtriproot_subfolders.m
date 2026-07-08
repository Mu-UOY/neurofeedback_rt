function test_live_add_fieldtrip_paths_adds_fieldtriproot_subfolders()
% TEST_LIVE_ADD_FIELDTRIP_PATHS_ADDS_FIELDTRIPROOT_SUBFOLDERS Check no genpath.

%% ===== BUILD FAKE FIELDTRIP TREE =====
oldPath = path;
tmpRoot = tempname;
mkdir(tmpRoot);
cleanupObj = onCleanup(@() local_cleanup(oldPath, tmpRoot)); %#ok<NASGU>

mkdir(fullfile(tmpRoot, 'realtime'));
bufferFolder = fullfile(tmpRoot, 'realtime', 'buffer', 'matlab');
mkdir(bufferFolder);
mkdir(fullfile(tmpRoot, 'fileio'));
mkdir(fullfile(tmpRoot, 'private_unexpected'));
local_write_fake_buffer(fullfile(bufferFolder, 'buffer.m'));

RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.Host = 'configured-host';
RTConfig.Source.FieldTrip.Port = 1;
RTConfig.Source.FieldTrip.SettingOrigin.Host = 'config';
RTConfig.Source.FieldTrip.SettingOrigin.Port = 'config';
RTConfig.Source.FieldTrip.FieldTripRoot = tmpRoot;
RTConfig.Source.FieldTrip.RequiredBufferRoot = bufferFolder;

PathInfo = nf_live_add_fieldtrip_paths(RTConfig);

expected = {tmpRoot, fullfile(tmpRoot, 'realtime'), bufferFolder, fullfile(tmpRoot, 'fileio')};
assert(strcmp(PathInfo.Status, 'PASS'), 'Fake FieldTrip path setup failed.');
assert(isempty(setdiff(expected, PathInfo.AddedPaths)), 'Expected subfolders were not added.');
assert(~any(strcmp(PathInfo.AddedPaths, fullfile(tmpRoot, 'private_unexpected'))), ...
    'Unexpected subfolder was added; helper may be using broad genpath behavior.');
assert(strcmp(PathInfo.SelectedBufferPath, fullfile(bufferFolder, 'buffer.m')), ...
    'Selected buffer.m was not the configured fake FieldTrip buffer.');

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
