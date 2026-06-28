function Measure = nf_measure_empty()
% NF_MEASURE_EMPTY Create one canonical empty Measure struct.
%
% USAGE:  Measure = nf_measure_empty()
%
% DESCRIPTION:
%     Returns the schema used for every per-chunk feedback Measure, with
%     numeric fields initialized to NaN, logical flags initialized false, and
%     optional payloads initialized empty.

%% ===== INITIALIZE MEASURE STRUCT =====
% Every downstream Measure starts from this canonical schema.
Measure = struct();

%% ===== POWER FIELDS =====
% Power is the scalar feedback power; PowerPerSignal keeps projected detail.
Measure.Power = NaN;
Measure.PowerPerSignal = [];

%% ===== FEEDBACK NORMALIZATION FIELDS =====
% Z-score fields remain NaN until a valid baseline is available.
Measure.ZRaw = NaN;
Measure.ZClipped = NaN;
Measure.ZSmoothed = NaN;
Measure.FeedbackValue = NaN;

%% ===== TIME FIELDS =====
% Time reports neural-window time after delay correction.
Measure.Time = NaN;
Measure.AcquisitionTime = NaN;
Measure.NeuralWindowTime = NaN;
Measure.FeedbackDisplayTime = NaN;

%% ===== SAMPLE INDEX FIELDS =====
% Raw and filtered sample indices preserve timing provenance.
Measure.SampleIndex = NaN;
Measure.AcquisitionSampleIndex = NaN;
Measure.FilteredSampleIndex = NaN;

%% ===== WINDOW FIELDS =====
% Window fields describe the uncorrected power-estimation window.
Measure.WindowStartSample = NaN;
Measure.WindowEndSample = NaN;
Measure.WindowCenterSample = NaN;

%% ===== DELAY-CORRECTED WINDOW FIELDS =====
% Corrected fields report the estimated neural-time window.
Measure.CorrectedWindowStartSample = NaN;
Measure.CorrectedWindowEndSample = NaN;
Measure.CorrectedWindowCenterSample = NaN;

%% ===== FILTER DELAY FIELDS =====
% Store both analytic and empirical delay metadata when available.
Measure.AnalyticGroupDelaySamples = NaN;
Measure.EmpiricalDelaySamples = NaN;
Measure.DelayCorrectionUsed = NaN;

%% ===== SOURCE AND BAND FIELDS =====
% SourceMode and Band identify where the measure came from and what it tracks.
Measure.SourceMode = '';
Measure.Band = [NaN NaN];

%% ===== QUALITY FLAGS =====
% InvalidReason explains why IsValid is false.
Measure.IsValid = false;
Measure.InvalidReason = '';
Measure.DroppedChunkFlag = false;
Measure.GapInWindowFlag = false;
Measure.ArtifactFlag = false;
Measure.TriggerSent = false;

%% ===== DIAGNOSTICS PAYLOAD =====
% Function-specific diagnostics are stored without changing the schema.
Measure.Diagnostics = struct();

end
