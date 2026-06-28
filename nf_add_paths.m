function projectRoot = nf_add_paths()
% NF_ADD_PATHS Add core project folders to the MATLAB path.
%
% USAGE:  projectRoot = nf_add_paths()
%
% DESCRIPTION:
%     Resolves the neurofeedback_rt project root, adds each source folder to
%     the MATLAB path, and ensures validation outputs have a destination.

%% ===== RESOLVE PROJECT ROOT =====
% mfilename('fullpath') returns this file path, so its folder is the root.
projectRoot = fileparts(mfilename('fullpath'));

%% ===== ADD SOURCE FOLDERS =====
% Keep the folder list explicit so startup behavior is easy to audit.
foldersToAdd = { ...
    'main', ...
    'config', ...
    'io', ...
    'source', ...
    'rt', ...
    'measure', ...
    'buffer', ...
    'sync', ...
    'spatial', ...
    'validation', ...
    'tests'};

for iFolder = 1:numel(foldersToAdd)
    folderPath = fullfile(projectRoot, foldersToAdd{iFolder});

    % Add existing project folders and warn on missing expected folders.
    if exist(folderPath, 'dir')
        addpath(folderPath);
    else
        warning('Project folder missing: %s', folderPath);
    end
end

%% ===== CREATE OUTPUT FOLDER =====
% Validation runs write timestamped MAT files under outputs/validation.
outDir = fullfile(projectRoot, 'outputs', 'validation');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

end
