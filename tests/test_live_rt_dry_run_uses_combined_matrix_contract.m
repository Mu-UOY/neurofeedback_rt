function test_live_rt_dry_run_uses_combined_matrix_contract()
% TEST_LIVE_RT_DRY_RUN_USES_COMBINED_MATRIX_CONTRACT Check fallback matrix shape.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Spatial.Fallback.Type = 'single_channel';
RTConfig.Spatial.Fallback.ChannelIndex = 2;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;

Source = local_source({'MEG001','MEG002','MEG003'});
Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);

assert(strcmp(RTConfig.Spatial.Mode, Modes.Spatial.CombinedMatrix), 'Spatial mode changed.');
assert(isequal(size(Spatial.CombinedMatrix), [1 3]), 'Fallback matrix size mismatch.');
assert(Spatial.CombinedMatrix(2) == 1, 'Fallback did not select channel 2.');
assert(Spatial.IsTechnicalFallback == true, 'Fallback flag was false.');
assert(Spatial.IsIPS == false, 'Technical fallback claimed IPS.');
assert(any(contains(lower(Spatial.Messages), 'technical fallback')), 'Missing fallback warning.');
end

function Source = local_source(names)
Source = struct();
Source.Fs = 2400;
Source.NChannels = numel(names);
Source.ChannelNames = names;
Source.ChannelNamesAfterCorrection = names;
Source.HeaderHash = 'header_a';
Source.CorrectionState = struct('AppliedChannelGains', false, ...
    'AppliedMegRefCorrection', false, 'AppliedProjector', false);
end
