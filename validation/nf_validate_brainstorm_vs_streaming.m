function Results = nf_validate_brainstorm_vs_streaming(Ref, Measures, RTConfig)
% NF_VALIDATE_BRAINSTORM_VS_STREAMING Compare offline reference and streaming output.
%
% USAGE:  Results = nf_validate_brainstorm_vs_streaming(Ref, Measures, RTConfig)
%
% DESCRIPTION:
%     Aligns valid streaming power values to the nearest offline reference
%     sample, computes agreement metrics, and assigns PASS/WARN/FAIL based
%     on configured correlation thresholds.

%% ===== INITIALIZE RESULTS =====
% Direct comparison uses uncorrected centers; corrected samples are for reporting.
Results = struct();
Results.AlignmentSampleField = 'WindowCenterSample';
Results.Note = ['Direct comparison uses uncorrected window centers; ', ...
    'corrected samples are for neural-time reporting.'];

%% ===== CHECK STREAMING MEASURES =====
% Without valid streaming output, there is nothing to compare.
if isempty(Measures)
    Results.Status = 'FAIL';
    Results.Message = 'No streaming measures.';
    return;
end

%% ===== EXTRACT VALID STREAMING SERIES =====
% Power and sample centers are compared window by window.
validMeasures = [Measures.IsValid] == true;
if ~any(validMeasures)
    Results.Status = 'FAIL';
    Results.Message = 'No valid streaming measures.';
    return;
end

streamPower = [Measures(validMeasures).Power];
streamSamples = [Measures(validMeasures).WindowCenterSample];

%% ===== ALIGN REFERENCE SERIES =====
% Align each streaming window to the nearest valid reference sample.
[refAligned, keepRef] = local_align_reference(Ref, streamSamples);
keep = keepRef & isfinite(refAligned) & isfinite(streamPower);

%% ===== CHECK COMPARISON COUNT =====
% Correlation needs at least two finite aligned samples.
Results.NCompared = nnz(keep);
if Results.NCompared < 2
    Results.Status = 'FAIL';
    Results.Message = 'Fewer than two finite aligned samples.';
    Results.Correlation = NaN;
    Results.RMSE = NaN;
    Results.MaxAbsDiff = NaN;
    return;
end

refAligned = refAligned(keep);
streamPower = streamPower(keep);

%% ===== COMPUTE AGREEMENT METRICS =====
% Correlation captures shape; RMSE and max difference capture scale errors.
Results.Correlation = local_corr(refAligned, streamPower);
Results.RMSE = sqrt(mean((refAligned - streamPower) .^ 2));
Results.MaxAbsDiff = max(abs(refAligned - streamPower));

%% ===== ASSIGN STATUS =====
% Thresholds are configured in RTConfig.Validation.
if Results.Correlation >= RTConfig.Validation.ExcellentCorrelation
    Results.Status = 'PASS';
elseif Results.Correlation >= RTConfig.Validation.MinAcceptableCorrelation
    Results.Status = 'WARN';
else
    Results.Status = 'FAIL';
end
Results.Message = sprintf('Compared %d streaming windows.', Results.NCompared);

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
