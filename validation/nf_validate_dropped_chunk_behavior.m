function Results = nf_validate_dropped_chunk_behavior(Measures, RTConfig)
% NF_VALIDATE_DROPPED_CHUNK_BEHAVIOR Summarize dropped/gapped Measure behavior.
%
% USAGE:  Results = nf_validate_dropped_chunk_behavior(Measures, RTConfig)
%
% DESCRIPTION:
%     Checks whether simulated dropped chunks produce invalid gap-contaminated
%     Measures, counts invalid reasons, and reports robust diagnostics without
%     requiring brittle sample-perfect accounting.

%% ===== INITIALIZE RESULTS =====
% Keep all expected fields present even when Measures is empty.
Results = struct();
Results.Status = 'PASS';
Results.Message = '';
Results.NMeasures = numel(Measures);
Results.NValidMeasures = 0;
Results.NInvalidMeasures = 0;
Results.NDroppedChunkFlags = 0;
Results.NGapWindowFlags = 0;
Results.NInvalidGapWindows = 0;
Results.InvalidReasonCounts = local_empty_reason_counts();
Results.DropSimulationEnabled = local_drop_enabled(RTConfig);
Results.ExpectedDropsConfigured = false;
Results.ExpectedDropChunkIndices = [];

if isfield(RTConfig, 'Simulation') && isfield(RTConfig.Simulation, 'DropChunkIndices') && ...
        ~isempty(RTConfig.Simulation.DropChunkIndices)
    Results.ExpectedDropChunkIndices = reshape(RTConfig.Simulation.DropChunkIndices, 1, []);
    Results.ExpectedDropsConfigured = Results.DropSimulationEnabled;
end

%% ===== HANDLE EMPTY MEASURES =====
% An empty validation run cannot certify drop behavior.
if isempty(Measures)
    if Results.DropSimulationEnabled && Results.ExpectedDropsConfigured
        Results.Status = 'WARN';
        Results.Message = 'Dropped chunks were configured, but no Measures were available.';
    else
        Results.Status = 'PASS';
        Results.Message = 'No Measures and no dropped chunks observed.';
    end
    return;
end

%% ===== COUNT MEASURE FLAGS =====
% Gap and dropped flags should make the associated Measure invalid.
isValid = [Measures.IsValid] == true;
gapFlags = [Measures.GapInWindowFlag] == true;
droppedFlags = [Measures.DroppedChunkFlag] == true;
gapOrDropped = gapFlags | droppedFlags;

Results.NValidMeasures = nnz(isValid);
Results.NInvalidMeasures = Results.NMeasures - Results.NValidMeasures;
Results.NDroppedChunkFlags = nnz(droppedFlags);
Results.NGapWindowFlags = nnz(gapFlags);
Results.NInvalidGapWindows = nnz(gapOrDropped & ~isValid);
Results.InvalidReasonCounts = local_count_invalid_reasons(Measures);

%% ===== FAIL INCONSISTENT VALID WINDOWS =====
% A gap-contaminated or dropped-window Measure must never be marked valid.
if any(gapFlags & isValid)
    Results.Status = 'FAIL';
    Results.Message = 'At least one Measure has GapInWindowFlag=true while IsValid=true.';
    return;
end
if any(droppedFlags & isValid)
    Results.Status = 'FAIL';
    Results.Message = 'At least one Measure has DroppedChunkFlag=true while IsValid=true.';
    return;
end

%% ===== ASSIGN STATUS =====
% Expected drops should create at least one invalid gap/dropped Measure, but
% exact counts depend on chunk size, window size, and drop position.
if ~Results.DropSimulationEnabled && Results.NDroppedChunkFlags == 0 && Results.NGapWindowFlags == 0
    Results.Status = 'PASS';
    Results.Message = 'Dropped-chunk simulation disabled; no dropped chunks observed.';
elseif Results.DropSimulationEnabled && Results.ExpectedDropsConfigured && Results.NInvalidGapWindows == 0
    Results.Status = 'WARN';
    Results.Message = 'Dropped chunks were configured, but no invalid gap-contaminated Measures were observed.';
elseif Results.NDroppedChunkFlags > 0 || Results.NGapWindowFlags > 0
    Results.Status = 'PASS';
    Results.Message = 'Dropped/gap flags were observed only on invalid Measures.';
else
    Results.Status = 'PASS';
    Results.Message = 'No dropped or gap-contaminated Measures observed.';
end

end

function enabled = local_drop_enabled(RTConfig)
% Read dropped-chunk simulation flag with older-config fallback.
enabled = false;
if isfield(RTConfig, 'Simulation') && isfield(RTConfig.Simulation, 'EnableDroppedChunks')
    enabled = logical(RTConfig.Simulation.EnableDroppedChunks);
end
end

function Counts = local_empty_reason_counts()
% Initialize common invalid reasons and an unknown bucket.
Counts = struct();
Counts.empty_window = 0;
Counts.buffer_not_full = 0;
Counts.filter_warmup = 0;
Counts.gap_in_window = 0;
Counts.nonfinite_window = 0;
Counts.nonfinite_power = 0;
Counts.unknown = 0;
end

function Counts = local_count_invalid_reasons(Measures)
% Count known and unknown invalid reason strings without throwing.
Counts = local_empty_reason_counts();
knownReasons = fieldnames(Counts);

for iMeasure = 1:numel(Measures)
    if Measures(iMeasure).IsValid
        continue;
    end

    reason = '';
    if isfield(Measures(iMeasure), 'InvalidReason') && ~isempty(Measures(iMeasure).InvalidReason)
        reason = char(Measures(iMeasure).InvalidReason);
    end

    if isempty(reason)
        reason = 'unknown';
    end

    reason = matlab.lang.makeValidName(reason);
    if any(strcmp(reason, knownReasons))
        Counts.(reason) = Counts.(reason) + 1;
    else
        Counts.unknown = Counts.unknown + 1;
        if ~isfield(Counts, reason)
            Counts.(reason) = 0;
        end
        Counts.(reason) = Counts.(reason) + 1;
    end
end
end
