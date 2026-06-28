function Measure = nf_rt_make_measure(Power, PowerPerSignal, IsValid, Diagnostics, chunk, RT, RTConfig)
% NF_RT_MAKE_MEASURE Package power and timing into the canonical Measure.
%
% USAGE:  Measure = nf_rt_make_measure(Power, PowerPerSignal, IsValid, Diagnostics, chunk, RT, RTConfig)
%
% DESCRIPTION:
%     Builds one canonical Measure from computed power, chunk timing,
%     diagnostic flags, filter delay metadata, and synchronized neural-time
%     fields.

%% ===== INITIALIZE MEASURE =====
% Start from the canonical Measure schema.
Measure = nf_measure_empty();

%% ===== COPY POWER VALUES =====
% Power validity is determined by nf_rt_compute_power.
Measure.Power = Power;
Measure.PowerPerSignal = PowerPerSignal;
Measure.IsValid = IsValid;

%% ===== COPY DIAGNOSTIC FLAGS =====
% Diagnostics may omit fields depending on the invalid path.
if isfield(Diagnostics, 'InvalidReason')
    Measure.InvalidReason = Diagnostics.InvalidReason;
end
if isfield(Diagnostics, 'GapInWindowFlag')
    Measure.GapInWindowFlag = Diagnostics.GapInWindowFlag;
end
if isfield(Diagnostics, 'DroppedChunkFlag')
    Measure.DroppedChunkFlag = Diagnostics.DroppedChunkFlag;
end

Measure.ArtifactFlag = false;
Measure.TriggerSent = false;
Measure.SourceMode = chunk.SourceMode;
Measure.Band = RTConfig.TargetBand;

%% ===== COPY FILTER DELAY METADATA =====
% Delay metadata is used for neural-time reporting.
Measure.AnalyticGroupDelaySamples = RT.Filter.AnalyticGroupDelaySamples;
Measure.EmpiricalDelaySamples = RT.Filter.EmpiricalDelaySamples;

%% ===== RESOLVE DELAY CORRECTION =====
% Fall back to analytic delay when explicit correction is unavailable.
D = RT.Filter.DelayCorrectionUsed;
if isempty(D) || ~isfinite(D)
    if isfinite(RT.Filter.AnalyticGroupDelaySamples)
        D = RT.Filter.AnalyticGroupDelaySamples;
    else
        D = 0;
    end
end
Measure.DelayCorrectionUsed = D;

%% ===== COMPUTE WINDOW SAMPLE INDICES =====
% The power window ends at the last sample in the current chunk.
W = RTConfig.PowerWindowSamples;
n = chunk.SampleIndex + chunk.NSamples - 1;

Measure.AcquisitionSampleIndex = n;
Measure.FilteredSampleIndex = n;

Measure.WindowEndSample = n;
Measure.WindowStartSample = n - W + 1;
Measure.WindowCenterSample = Measure.WindowStartSample + floor(W / 2);

%% ===== COMPUTE DELAY-CORRECTED WINDOW INDICES =====
% Corrected fields estimate the neural-time window after filter delay.
Measure.CorrectedWindowEndSample = n - D;
Measure.CorrectedWindowStartSample = n - D - W + 1;
Measure.CorrectedWindowCenterSample = Measure.CorrectedWindowStartSample + floor(W / 2);

%% ===== ATTACH FINAL METADATA =====
% SampleIndex keeps acquisition-time indexing for compatibility.
Measure.SampleIndex = Measure.AcquisitionSampleIndex;
Measure.Diagnostics = Diagnostics;

%% ===== ATTACH TIMESTAMPS =====
% Synchronization helper computes neural and acquisition time fields.
Measure = nf_sync_timestamp(Measure, chunk, RT, RTConfig);

end
