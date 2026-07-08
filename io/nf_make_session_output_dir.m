function Session = nf_make_session_output_dir(RTConfig, sessionLabel)
% NF_MAKE_SESSION_OUTPUT_DIR Create a unique live-session output folder.
%
% USAGE:  Session = nf_make_session_output_dir(RTConfig, sessionLabel)
%
% DESCRIPTION:
%     Creates the session directory tree used by the Step 3 logging scaffold.
%     The folder is collision-safe and does not overwrite existing outputs.

%% ===== PARSE SESSION LABEL =====
% Labels become part of folder names, so keep only stable filename characters.
if nargin < 2 || isempty(sessionLabel)
    sessionLabel = 'session';
end
label = local_sanitize_label(sessionLabel);

%% ===== RESOLVE OUTPUT ROOT =====
% Tests can override RTConfig.Paths.ProjectRoot before logger creation.
projectRoot = local_project_root(RTConfig);
outputRoot = fullfile(projectRoot, 'outputs', 'live');
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

%% ===== CREATE COLLISION-SAFE SESSION FOLDER =====
% Folder existence, not timestamp alone, controls uniqueness.
createdAtFile = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
createdAtHuman = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
baseName = [createdAtFile '_' label];
sessionDir = fullfile(outputRoot, baseName);
suffix = 0;
while exist(sessionDir, 'dir') ~= 0
    suffix = suffix + 1;
    sessionDir = fullfile(outputRoot, sprintf('%s_%03d', baseName, suffix));
end
mkdir(sessionDir);

%% ===== CREATE REQUIRED SUBFOLDERS =====
% Keep the tree explicit so live-room artifacts are easy to inspect.
Session = struct();
Session.Label = label;
Session.CreatedAt = createdAtHuman;
Session.ProjectRoot = projectRoot;
Session.OutputRoot = outputRoot;
Session.SessionDir = sessionDir;
Session.ConfigDir = fullfile(sessionDir, 'config');
Session.SourceDir = fullfile(sessionDir, 'source');
Session.BaselineDir = fullfile(sessionDir, 'baseline');
Session.TrialDir = fullfile(sessionDir, 'trial');
Session.LogsDir = fullfile(sessionDir, 'logs');
Session.TracesDir = fullfile(sessionDir, 'traces');
Session.ReportsDir = fullfile(sessionDir, 'reports');
Session.DebugChunksDir = fullfile(sessionDir, 'debug_chunks');
Session.IsPartial = true;
Session.Finalized = false;
Session.Messages = {};

folders = {'ConfigDir','SourceDir','BaselineDir','TrialDir','LogsDir', ...
    'TracesDir','ReportsDir','DebugChunksDir'};
for iFolder = 1:numel(folders)
    mkdir(Session.(folders{iFolder}));
end

end

function label = local_sanitize_label(labelIn)
% Replace unsupported filename characters with underscores.
label = char(labelIn);
label = regexprep(label, '[^a-zA-Z0-9_-]', '_');
label = regexprep(label, '_+', '_');
label = regexprep(label, '^_+|_+$', '');
if isempty(label)
    label = 'session';
end
end

function projectRoot = local_project_root(RTConfig)
% Resolve project root using the Step 3A-0d priority order.
projectRoot = '';
if nargin >= 1 && isstruct(RTConfig) && isfield(RTConfig, 'Paths') && ...
        isstruct(RTConfig.Paths) && isfield(RTConfig.Paths, 'ProjectRoot') && ...
        ~isempty(RTConfig.Paths.ProjectRoot)
    projectRoot = char(RTConfig.Paths.ProjectRoot);
elseif exist('nf_project_root', 'file') ~= 0
    projectRoot = nf_project_root();
else
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end
end
