function [X, CorrectionInfo] = nf_live_apply_ben_ctf_corrections(Xraw, Source, RTConfig)
% NF_LIVE_APPLY_BEN_CTF_CORRECTIONS Candidate Ben-compatible correction path.
%
% USAGE:  [X, CorrectionInfo] = nf_live_apply_ben_ctf_corrections(Xraw, Source, RTConfig)
%
% Candidate Ben-compatible correction path.
%
% This function is intentionally conservative. It may apply:
% 1. ChannelGains correction
% 2. MEG reference correction using MegRefCoef
% 3. Block mean removal
% 4. Optional projector, disabled by default
%
% This order must be confirmed against Benjamin's code and with Marc before
% claiming it matches the real historical live preprocessing.

%% ===== INITIALIZE OUTPUT =====
X = double(Xraw);
CorrectionInfo = struct();
CorrectionInfo.AppliedChannelGains = false;
CorrectionInfo.AppliedMegRefCorrection = false;
CorrectionInfo.RemovedBlockMean = false;
CorrectionInfo.AppliedProjector = false;
CorrectionInfo.InputNChannels = size(Xraw, 1);
CorrectionInfo.OutputNChannels = size(X, 1);
CorrectionInfo.InputChannelNames = local_field(Source, 'ChannelNames', {});
CorrectionInfo.OutputChannelNames = local_field(Source, 'ChannelNamesAfterCorrection', {});
CorrectionInfo.RequiresMarcConfirmation = RTConfig.Source.CTF.RequireMarcConfirmation;
CorrectionInfo.MarcConfirmed = RTConfig.Source.CTF.MarcConfirmed;
CorrectionInfo.CorrectionOrder = RTConfig.Source.CTF.CorrectionOrder;
CorrectionInfo.Messages = {};

if CorrectionInfo.RequiresMarcConfirmation && ~CorrectionInfo.MarcConfirmed
    CorrectionInfo.Messages{end+1} = ...
        'Candidate correction path requires Marc confirmation before claiming Benjamin equivalence.';
end

%% ===== CHANNEL GAINS =====
% Benjamin code was not available here, so the gain convention is unresolved.
if RTConfig.Source.CTF.ApplyChannelGains
    gains = local_field(Source, 'ChannelGains', []);
    if isempty(gains)
        CorrectionInfo.Messages{end+1} = ...
            'ChannelGains metadata unavailable; correction skipped.';
    else
        CorrectionInfo.Messages{end+1} = ...
            'ChannelGains convention unresolved; correction skipped or requires Marc confirmation.';
    end
end

%% ===== MEG REFERENCE CORRECTION =====
% Keep the scaffold explicit, but do not guess indexing/conventions.
if RTConfig.Source.CTF.ApplyMegRefCorrection
    megRefCoef = local_field(Source, 'MegRefCoef', []);
    iMeg = local_field(Source, 'iMeg', []);
    iMegRef = local_field(Source, 'iMegRef', []);
    if isempty(megRefCoef) || isempty(iMeg) || isempty(iMegRef)
        CorrectionInfo.Messages{end+1} = ...
            'MEG reference metadata incomplete; correction skipped.';
    else
        CorrectionInfo.Messages{end+1} = ...
            'MEG reference correction convention unresolved; correction skipped pending Marc confirmation.';
    end
end

%% ===== BLOCK MEAN REMOVAL =====
% Block mean removal is dimension-preserving and independent of CTF metadata.
if RTConfig.Source.CTF.RemoveBlockMean && ~isempty(X)
    X = X - mean(X, 2);
    CorrectionInfo.RemovedBlockMean = true;
end

%% ===== OPTIONAL PROJECTOR =====
% Projector application is deliberately disabled unless explicitly configured.
if RTConfig.Source.CTF.ApplyProjector
    CorrectionInfo.Messages{end+1} = ...
        'Projector correction is configured but no live projector is available in Step 3A.';
end

CorrectionInfo.OutputNChannels = size(X, 1);
if isempty(CorrectionInfo.OutputChannelNames)
    CorrectionInfo.OutputChannelNames = CorrectionInfo.InputChannelNames;
end

end

function value = local_field(S, fieldName, defaultValue)
% Read optional struct field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
