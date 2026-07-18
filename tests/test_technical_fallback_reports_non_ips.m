function test_technical_fallback_reports_non_ips()
% TEST_TECHNICAL_FALLBACK_REPORTS_NON_IPS Check fallback audit wording.

%% ===== PREPARE TECHNICAL FALLBACK =====
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
Source = local_source({'MEG001','MEG002'}, 'header_a');

Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);

assert(Spatial.IsTechnicalFallback == true, 'Technical fallback flag missing.');
assert(Spatial.IsIPS == false, 'Technical fallback claimed IPS.');
assert(~isempty(Spatial.Messages), 'Technical fallback message missing.');
assert(contains(Spatial.Messages{1}, 'do not claim IPS'), ...
    'Technical fallback message does not clearly reject IPS claims.');

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
