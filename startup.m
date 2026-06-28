% STARTUP Add neurofeedback_rt folders to the MATLAB path.
%
% USAGE:
%     startup
%
% DESCRIPTION:
%     Adds the project folders to the MATLAB path, prints the resolved
%     project root, and warns if optional Brainstorm functions are missing.

%% ===== ADD PROJECT PATHS =====
% Add core neurofeedback_rt folders and create the validation output folder.
projectRoot = nf_add_paths();

%% ===== PRINT STARTUP SUMMARY =====
% Report the active project root so users can confirm MATLAB started in the
% expected repository checkout.
fprintf('neurofeedback_rt paths added.\n');
fprintf('Project root: %s\n', projectRoot);

%% ===== CHECK OPTIONAL DEPENDENCIES =====
% Brainstorm is only required for Brainstorm FIR filter mode.
if exist('brainstorm', 'file') == 0
    warning('Brainstorm is not on the MATLAB path. This is OK for iir_sos or none filter modes.');
end

%% ===== PRINT STARTUP TIME =====
% Include a timestamp when the MATLAB runtime supports datetime.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    fprintf('Startup time: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end
