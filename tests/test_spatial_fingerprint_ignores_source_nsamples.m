function test_spatial_fingerprint_ignores_source_nsamples()
% TEST_SPATIAL_FINGERPRINT_IGNORES_SOURCE_NSAMPLES Check stable source identity.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;

SourceA = local_source({'MEG001','MEG002'}, 1000);
SourceB = local_source({'MEG001','MEG002'}, 2000);

Spatial = nf_prepare_live_combined_matrix(SourceA, RTConfig);
Spatial2 = nf_revalidate_live_spatial_against_source(Spatial, SourceB, RTConfig);

assert(strcmp(Spatial.LiveHeaderFingerprint, Spatial2.LiveHeaderFingerprint), ...
    'Spatial fingerprint changed with source NSamples.');
end

function Source = local_source(names, nSamples)
Header = struct('Fs', 2400, 'NChannels', numel(names), 'ChannelNames', {names}, 'NSamples', nSamples);
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
Source.CorrectionState = local_correction_state();
end

function State = local_correction_state()
State = struct('AppliedChannelGains', false, 'AppliedMegRefCorrection', false, ...
    'RemovedBlockMean', false, 'AppliedProjector', false, ...
    'RequiresMarcConfirmation', true, 'MarcConfirmed', false);
end
