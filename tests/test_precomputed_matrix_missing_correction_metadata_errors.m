function test_precomputed_matrix_missing_correction_metadata_errors()
% TEST_PRECOMPUTED_MATRIX_MISSING_CORRECTION_METADATA_ERRORS Check fail-closed load.

%% ===== CREATE INCOMPLETE PRECOMPUTED MATRIX =====
Modes = nf_modes();
tmpPath = [tempname, '.mat'];
cleanupObj = onCleanup(@() local_cleanup(tmpPath));

Spatial = struct();
Spatial.CombinedMatrix = eye(2);
Spatial.InputChannelNames = {'MEG001','MEG002'};
Spatial.LiveHeaderHash = 'header_a';
Spatial.IsIPS = true;
save(tmpPath, 'Spatial');

RTConfig = nf_live_config();
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = tmpPath;
Source = local_source({'MEG001','MEG002'}, 'header_a');

didError = false;
try
    nf_prepare_live_combined_matrix(Source, RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'CorrectionState'), ...
        'Unexpected missing metadata error: %s', ME.message);
end
assert(didError, 'Precomputed matrix without CorrectionState was accepted.');

clear cleanupObj
end

function Source = local_source(names, hashValue)
Source = struct();
Source.Fs = 2400;
Source.NChannels = numel(names);
Source.ChannelNames = names;
Source.ChannelNamesAfterCorrection = names;
Source.HeaderHash = hashValue;
Source.CorrectionState = struct('AppliedChannelGains', false, ...
    'AppliedMegRefCorrection', false, 'RemovedBlockMean', false, ...
    'AppliedProjector', false, 'RequiresMarcConfirmation', true, ...
    'MarcConfirmed', false);
end

function local_cleanup(pathValue)
if exist(pathValue, 'file') == 2
    delete(pathValue);
end
end
