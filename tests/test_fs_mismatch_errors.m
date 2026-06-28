function test_fs_mismatch_errors()
% TEST_FS_MISMATCH_ERRORS Ensure validation loading rejects Fs mismatches.
%
% USAGE:  test_fs_mismatch_errors()
%
% DESCRIPTION:
%     Saves a temporary dataset with one sampling rate and confirms
%     nf_load_validation_data rejects it when RTConfig.Fs differs.

%% ===== CREATE TEMPORARY DATASET =====
% onCleanup removes the MAT file after the test exits.
tmpFile = [tempname, '.mat'];
cleanupObj = onCleanup(@() local_delete(tmpFile)); %#ok<NASGU>

X = randn(2, 100); %#ok<NASGU>
Fs = 1000; %#ok<NASGU>
save(tmpFile, 'X', 'Fs');

%% ===== CONFIGURE MISMATCH =====
% RTConfig.Fs intentionally disagrees with the saved Fs.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = 1200;
RTConfig.Source.DatasetPath = tmpFile;

%% ===== CHECK ERROR MESSAGE =====
% The loader should hard-error before processing mismatched samples.
didError = false;
try
    nf_load_validation_data(RTConfig);
catch ME
    didError = ~isempty(strfind(ME.message, 'does not match')); %#ok<STREMP>
end

assert(didError, 'nf_load_validation_data did not hard-error on Fs mismatch.');

end

function local_delete(pathToDelete)
% Delete the temporary dataset if it still exists.
if exist(pathToDelete, 'file')
    delete(pathToDelete);
end
end
