function test_spatial_fingerprint_rejects_channel_reorder()
% TEST_SPATIAL_FINGERPRINT_REJECTS_CHANNEL_REORDER Check layout drift rejection.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;

SourceA = local_source({'MEG001','MEG002'});
SourceB = local_source({'MEG002','MEG001'});
Spatial = nf_prepare_live_combined_matrix(SourceA, RTConfig);

didError = false;
try
    nf_revalidate_live_spatial_against_source(Spatial, SourceB, RTConfig);
catch ME
    didError = true;
    assert(contains(lower(ME.message), 'mismatch'), ...
        'Unexpected channel reorder error: %s', ME.message);
end
assert(didError, 'Channel reorder was accepted.');
end

function Source = local_source(names)
Header = struct('Fs', 2400, 'NChannels', numel(names), 'ChannelNames', {names});
[fp, inputs, version] = nf_live_header_fingerprint(Header);
Source = struct();
Source.Fs = 2400;
Source.NChannels = numel(names);
Source.ChannelNames = names;
Source.ChannelNamesAfterCorrection = names;
Source.HeaderFingerprint = fp;
Source.HeaderFingerprintInputs = inputs;
Source.HeaderFingerprintVersion = version;
Source.HeaderHash = fp;
Source.CorrectionState = struct('AppliedChannelGains', false, ...
    'AppliedMegRefCorrection', false, 'RemovedBlockMean', false, ...
    'AppliedProjector', false, 'RequiresMarcConfirmation', true, ...
    'MarcConfirmed', false);
end
