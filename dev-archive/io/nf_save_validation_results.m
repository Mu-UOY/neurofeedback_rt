function outFile = nf_save_validation_results(Ref, Measures, Results, RTConfig)
% NF_SAVE_VALIDATION_RESULTS Save validation outputs to a timestamped MAT file.
%
% USAGE:  outFile = nf_save_validation_results(Ref, Measures, Results, RTConfig)
%
% DESCRIPTION:
%     Ensures the validation output folder exists, writes the reference,
%     streaming measures, results, config, and save timestamp to a MAT file,
%     then optionally prints the saved path.

%% ===== ENSURE OUTPUT DIRECTORY =====
% ValidationDir is configured by nf_default_config/nf_check_config.
outDir = RTConfig.Paths.ValidationDir;
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ===== BUILD OUTPUT PATH =====
% Timestamped filenames keep validation runs from overwriting each other.
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outFile = fullfile(outDir, ['nf_validation_', stamp, '.mat']);

%% ===== SAVE RESULTS =====
% SavedAt is included as a top-level MAT variable for quick provenance checks.
SavedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')); %#ok<NASGU>
save(outFile, 'Ref', 'Measures', 'Results', 'RTConfig', 'SavedAt');

%% ===== PRINT SUMMARY =====
% Keep console output conditional on verbose debug mode.
if RTConfig.Debug.Verbose
    fprintf('Saved validation results: %s\n', outFile);
end

end
