function test_baseline_update_rejects_flagged_valid_measures()
% TEST_BASELINE_UPDATE_REJECTS_FLAGGED_VALID_MEASURES Check defensive guards.

%% ===== INITIALIZE BASELINE ACCUMULATOR =====
% Flagged windows must be counted as invalid even when IsValid is true.
RTConfig = nf_default_config();
BaselineAcc = nf_baseline_init(RTConfig);
baseMeasure = local_clean_valid_measure();

%% ===== REJECT GAP FLAG =====
% A gapped window is not eligible for baseline accumulation.
Measure = baseMeasure;
Measure.GapInWindowFlag = true;
BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig);
assert(isempty(BaselineAcc.Values), 'Gap-flagged valid Measure entered baseline values.');
assert(BaselineAcc.InvalidWindowCount == 1, 'Gap rejection did not increment invalid count.');
assert(BaselineAcc.GapWindowCount == 1, 'Gap rejection did not increment gap count.');
assert(isfield(BaselineAcc.InvalidReasonCounts, 'gap_in_window'), ...
    'Gap rejection reason was not recorded.');

%% ===== REJECT ARTIFACT FLAG =====
% Artifact-contaminated windows remain excluded from baseline powers.
Measure = baseMeasure;
Measure.ArtifactFlag = true;
BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig);
assert(isempty(BaselineAcc.Values), 'Artifact-flagged valid Measure entered baseline values.');
assert(BaselineAcc.InvalidWindowCount == 2, 'Artifact rejection did not increment invalid count.');
assert(BaselineAcc.ArtifactWindowCount == 1, 'Artifact rejection did not increment artifact count.');
assert(isfield(BaselineAcc.InvalidReasonCounts, 'artifact'), ...
    'Artifact rejection reason was not recorded.');

%% ===== REJECT DROPPED-CHUNK FLAG =====
% DroppedChunkFlag is a defensive exclusion in case validity flags diverge.
Measure = baseMeasure;
Measure.DroppedChunkFlag = true;
BaselineAcc = nf_baseline_update(BaselineAcc, Measure, RTConfig);
assert(isempty(BaselineAcc.Values), 'Dropped-chunk valid Measure entered baseline values.');
assert(BaselineAcc.InvalidWindowCount == 3, 'Dropped-chunk rejection did not increment invalid count.');
assert(BaselineAcc.ValidWindowCount == 0, 'Flagged Measures were counted as valid baseline windows.');
assert(isfield(BaselineAcc.InvalidReasonCounts, 'dropped_chunk'), ...
    'Dropped-chunk rejection reason was not recorded.');

end

function Measure = local_clean_valid_measure()
% Create a valid finite-power Measure whose flags can be toggled by tests.
Measure = struct();
Measure.IsValid = true;
Measure.Power = 1e-26;
Measure.GapInWindowFlag = false;
Measure.ArtifactFlag = false;
Measure.DroppedChunkFlag = false;
Measure.InvalidReason = '';
end
