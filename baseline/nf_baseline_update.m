function BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig) %#ok<INUSD>
% NF_BASELINE_UPDATE Add one Measure to a baseline accumulator.
%
% USAGE:  BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig)
%
% DESCRIPTION:
%     Appends finite valid Measure.Power values and counts invalid, gapped, or
%     artifact windows without letting those values enter the baseline.

%% ===== COUNT GAP AND ARTIFACT FLAGS =====
% These counters are independent of whether the Measure has a finite power.
if isfield(Measure, 'GapInWindowFlag') && Measure.GapInWindowFlag
    BaselineAcc.GapWindowCount = BaselineAcc.GapWindowCount + 1;
end
if isfield(Measure, 'ArtifactFlag') && Measure.ArtifactFlag
    BaselineAcc.ArtifactWindowCount = BaselineAcc.ArtifactWindowCount + 1;
end

%% ===== APPEND VALID POWER =====
% Resting baseline uses only clean valid finite power windows.
isValid = isfield(Measure, 'IsValid') && Measure.IsValid;
hasFinitePower = isfield(Measure, 'Power') && isfinite(Measure.Power);
hasGap = isfield(Measure, 'GapInWindowFlag') && Measure.GapInWindowFlag;
hasArtifact = isfield(Measure, 'ArtifactFlag') && Measure.ArtifactFlag;
hasDroppedChunk = isfield(Measure, 'DroppedChunkFlag') && Measure.DroppedChunkFlag;
isClean = ~hasGap && ~hasArtifact && ~hasDroppedChunk;

if isValid && hasFinitePower && isClean
    BaselineAcc.Values(end + 1) = Measure.Power;
    BaselineAcc.ValidWindowCount = BaselineAcc.ValidWindowCount + 1;
    return;
end

%% ===== COUNT INVALID WINDOW =====
% Invalid reason counts help diagnose failed baseline quality.
BaselineAcc.InvalidWindowCount = BaselineAcc.InvalidWindowCount + 1;
reason = 'unknown';
if isValid && hasFinitePower && ~isClean
    if hasGap
        reason = 'gap_in_window';
    elseif hasArtifact
        reason = 'artifact';
    else
        reason = 'dropped_chunk';
    end
elseif isfield(Measure, 'InvalidReason') && ~isempty(Measure.InvalidReason)
    reason = char(Measure.InvalidReason);
end
reason = matlab.lang.makeValidName(reason);
if ~isfield(BaselineAcc.InvalidReasonCounts, reason)
    BaselineAcc.InvalidReasonCounts.(reason) = 0;
end
BaselineAcc.InvalidReasonCounts.(reason) = BaselineAcc.InvalidReasonCounts.(reason) + 1;

end
