function test_revalidate_live_spatial_against_source_rejects_mismatch()
% TEST_REVALIDATE_LIVE_SPATIAL_AGAINST_SOURCE_REJECTS_MISMATCH Check channel order.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Spatial.Fallback.Type = 'single_channel';
RTConfig.Spatial.Fallback.ChannelIndex = 1;

SourceA = local_source({'MEG001','MEG002'}, 'header_a');
Spatial = nf_prepare_live_combined_matrix(SourceA, RTConfig);
SourceB = local_source({'MEG002','MEG001'}, 'header_a');

didError = false;
try
    nf_revalidate_live_spatial_against_source(Spatial, SourceB, RTConfig);
catch ME
    didError = true;
    assert(contains(lower(ME.message), 'mismatch'), ...
        'Unexpected spatial mismatch error: %s', ME.message);
end
assert(didError, 'Spatial channel-order mismatch was accepted.');

%% ===== PRECOMPUTED-STYLE MATRIX ALSO REJECTS MISMATCH =====
SpatialReal = struct();
SpatialReal.CombinedMatrix = eye(2);
SpatialReal.InputChannelNames = {'MEG001','MEG002'};
SpatialReal.OutputSignalNames = {'sig1','sig2'};
SpatialReal.LiveHeaderHash = 'header_a';
SpatialReal.CorrectionState = SourceA.CorrectionState;
SpatialReal.IsIPS = true;
SpatialReal.IsTechnicalFallback = false;

didError = false;
try
    nf_revalidate_live_spatial_against_source(SpatialReal, SourceB, RTConfig);
catch ME
    didError = true;
    assert(contains(lower(ME.message), 'mismatch'), ...
        'Unexpected real spatial mismatch error: %s', ME.message);
end
assert(didError, 'Real spatial channel-order mismatch was accepted.');
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
