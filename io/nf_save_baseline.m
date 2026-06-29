function outFile = nf_save_baseline(Baseline, RTConfig)
% NF_SAVE_BASELINE Save a finalized resting baseline.
%
% USAGE:  outFile = nf_save_baseline(Baseline, RTConfig)
%
% DESCRIPTION:
%     Saves a finalized nonpartial baseline to RTConfig.Paths.BaselinesDir.

%% ===== CHECK BASELINE =====
% Only finalized, quality-passing baselines are written to disk.
if ~isstruct(Baseline) || ~isfield(Baseline, 'Type') || ~strcmp(Baseline.Type, 'baseline')
    error('Baseline must be a baseline struct.');
end
if isfield(Baseline, 'Partial') && Baseline.Partial
    error('Cannot save a partial baseline.');
end
if ~isfield(Baseline, 'Finalized') || ~Baseline.Finalized
    error('Cannot save an unfinalized baseline.');
end
if isfield(Baseline, 'Quality') && isfield(Baseline.Quality, 'Pass') && ~Baseline.Quality.Pass
    error('Cannot save a baseline whose quality check failed.');
end

%% ===== BUILD OUTPUT PATH =====
% Baselines are timestamped and kept under the configured baselines folder.
outDir = RTConfig.Paths.BaselinesDir;
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

SavedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')); %#ok<NASGU>
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outFile = fullfile(outDir, ['baseline_', stamp, '.mat']);

%% ===== SAVE MAT FILE =====
% Save RTConfig with the baseline for later auditability.
save(outFile, 'Baseline', 'RTConfig', 'SavedAt');

end
