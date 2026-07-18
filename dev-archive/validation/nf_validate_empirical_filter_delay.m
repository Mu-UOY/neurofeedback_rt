function Results = nf_validate_empirical_filter_delay(Ref, Measures, RTConfig)
% NF_VALIDATE_EMPIRICAL_FILTER_DELAY Estimate reference-to-streaming lag.
%
% Positive lag means the streaming output is delayed relative to reference.
%
% USAGE:  Results = nf_validate_empirical_filter_delay(Ref, Measures, RTConfig)
%
% DESCRIPTION:
%     Aligns valid streaming measures to the offline reference, estimates the
%     lag with the highest correlation, and reports the corresponding delay
%     in samples.

%% ===== INITIALIZE RESULTS =====
% Store the sign convention directly in the output struct.
Results = struct();
Results.SignConvention = 'Positive lag means streaming output is delayed relative to reference.';

%% ===== CHECK STREAMING MEASURES =====
% Delay estimation requires at least a few valid streaming windows.
if isempty(Measures)
    Results.Pass = false;
    Results.Message = 'No streaming measures.';
    return;
end

%% ===== EXTRACT VALID STREAMING SERIES =====
% Use uncorrected window centers for direct reference alignment.
validMeasures = [Measures.IsValid] == true;
if nnz(validMeasures) < 3
    Results.Pass = false;
    Results.Message = 'Too few valid measures.';
    return;
end

streamPower = [Measures(validMeasures).Power];
streamSamples = [Measures(validMeasures).WindowCenterSample];

%% ===== ALIGN REFERENCE SERIES =====
% Align the offline reference to the streaming sample positions.
[refAligned, keepRef] = local_align_reference(Ref, streamSamples);
keep = keepRef & isfinite(refAligned) & isfinite(streamPower);

refAligned = refAligned(keep);
streamPower = streamPower(keep);
streamSamples = streamSamples(keep);

%% ===== CHECK ALIGNED SAMPLE COUNT =====
% Lag estimation needs enough finite samples after alignment.
if numel(streamPower) < 3
    Results.Pass = false;
    Results.Message = 'Too few finite aligned samples.';
    return;
end

%% ===== ESTIMATE SAMPLE STEP =====
% Convert lag steps back into sample units.
sampleStep = median(diff(streamSamples));
if isempty(sampleStep) || ~isfinite(sampleStep) || sampleStep <= 0
    sampleStep = RTConfig.ChunkSamples;
end

%% ===== FIND BEST LAG =====
% Search a bounded lag range set by RTConfig.Validation.MaxLagSamples.
maxLagSteps = min(numel(streamPower) - 2, ceil(RTConfig.Validation.MaxLagSamples ./ sampleStep));
[bestLagSteps, peak] = local_lag_corr(refAligned, streamPower, maxLagSteps);

%% ===== PACKAGE RESULTS =====
% Positive lag means streaming output trails the reference.
Results.BestLagSteps = bestLagSteps;
Results.StreamSampleStep = sampleStep;
Results.EmpiricalDelaySamples = bestLagSteps .* sampleStep;
Results.XCorrPeak = peak;
Results.Pass = isfinite(Results.EmpiricalDelaySamples) && isfinite(peak);
Results.Message = sprintf('Best lag = %g samples (%d stream steps).', ...
    Results.EmpiricalDelaySamples, bestLagSteps);

end

function [refAligned, keep] = local_align_reference(Ref, streamSamples)
% Align each streaming sample to the nearest valid offline reference sample.
refValid = Ref.IsValid == true;
refSamples = Ref.SampleIndex(refValid);
refPower = Ref.Power(refValid);

refAligned = NaN(size(streamSamples));
keep = false(size(streamSamples));
if isempty(refSamples)
    return;
end

for i = 1:numel(streamSamples)
    [~, idx] = min(abs(refSamples - streamSamples(i)));
    refAligned(i) = refPower(idx);
    keep(i) = true;
end
end

function [bestLag, peak] = local_lag_corr(ref, stream, maxLag)
% Compute correlation scores across integer lag steps.
lags = -maxLag:maxLag;
scores = NaN(size(lags));

for iLag = 1:numel(lags)
    lag = lags(iLag);
    if lag >= 0
        x = ref(1:(end - lag));
        y = stream((1 + lag):end);
    else
        d = -lag;
        x = ref((1 + d):end);
        y = stream(1:(end - d));
    end
    scores(iLag) = local_corr(x, y);
end

[peak, idx] = max(scores);
bestLag = lags(idx);
end

function r = local_corr(x, y)
% Compute scalar correlation while rejecting degenerate vectors.
x = x(:);
y = y(:);
if numel(x) < 2 || std(x) == 0 || std(y) == 0
    r = NaN;
    return;
end
C = corrcoef(x, y);
r = C(1, 2);
end
