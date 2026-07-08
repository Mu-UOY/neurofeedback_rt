function test_prepare_live_combined_matrix_technical_fallback_contract()
% TEST_PREPARE_LIVE_COMBINED_MATRIX_TECHNICAL_FALLBACK_CONTRACT Check schema.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Spatial.Fallback.Type = 'single_channel';
RTConfig.Spatial.Fallback.ChannelIndex = 1;

Source = local_source({'MEG001','MEG002'});
Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);

required = {'CombinedMatrix','InputChannelNames','OutputSignalNames','Hash', ...
    'MatrixSource','ValidatedAgainstLiveHeader','CorrectionState', ...
    'LiveHeaderHash','IsIPS','IsTechnicalFallback','Messages'};
for iField = 1:numel(required)
    assert(isfield(Spatial, required{iField}), 'Missing Spatial field: %s', required{iField});
end
assert(size(Spatial.CombinedMatrix, 2) == numel(Source.ChannelNamesAfterCorrection), ...
    'Matrix column count did not match corrected channels.');
assert(Spatial.IsIPS == false, 'Technical fallback claimed IPS.');
assert(Spatial.IsTechnicalFallback == true, 'Technical fallback flag was false.');
assert(Spatial.ValidatedAgainstLiveHeader == true, 'Spatial was not header-validated.');
end

function Source = local_source(names)
Source = struct();
Source.Fs = 2400;
Source.NChannels = numel(names);
Source.ChannelNames = names;
Source.ChannelNamesAfterCorrection = names;
Source.HeaderHash = 'header_contract';
Source.CorrectionState = struct('AppliedChannelGains', false, ...
    'AppliedMegRefCorrection', false, 'AppliedProjector', false);
end
