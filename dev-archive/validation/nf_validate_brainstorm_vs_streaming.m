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
Results.AlignmentToleranceSamples = floor(local_get_reference_step_samples(RTConfig) ./ 2);
Results.NCompared = 0;
Results.NUnmatched = 0;
Results.NExactMatches = 0;
Results.NToleranceMatches = 0;
Results.MaxSampleMismatch = NaN;
Results.ReferenceStrideMode = local_get_reference_stride_mode(RTConfig, Ref);
Results.ReferenceStepSamples = local_get_reference_step_samples(RTConfig);
Results.AlignmentStatus = 'FAIL';
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
[refAligned, keepRef, Alignment] = local_align_reference( ...
    Ref, streamSamples, Results.AlignmentToleranceSamples);
keep = keepRef & isfinite(refAligned) & isfinite(streamPower);

Results.NUnmatched = Alignment.NUnmatched;
Results.NExactMatches = Alignment.NExactMatches;
Results.NToleranceMatches = Alignment.NToleranceMatches;
Results.MaxSampleMismatch = Alignment.MaxSampleMismatch;

%% ===== CHECK COMPARISON COUNT =====
% Correlation needs at least two finite aligned samples.
Results.NCompared = nnz(keep);
if Results.NCompared < 2
    Results.Status = 'FAIL';
    Results.AlignmentStatus = 'FAIL';
    Results.Message = 'Fewer than two finite aligned samples.';
    Results.Correlation = NaN;
    Results.RMSE = NaN;
    Results.MaxAbsDiff = NaN;
    return;
end

refAligned = refAligned(keep);
streamPower = streamPower(keep);

if Results.NUnmatched > 0
    Results.AlignmentStatus = 'WARN';
else
    Results.AlignmentStatus = 'PASS';
end

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
if strcmp(Results.Status, 'PASS') && strcmp(Results.AlignmentStatus, 'WARN')
    Results.Status = 'WARN';
end
Results.Message = sprintf('Compared %d streaming windows; %d unmatched by sample tolerance.', ...
    Results.NCompared, Results.NUnmatched);

end

function [refAligned, keep, Alignment] = local_align_reference(Ref, streamSamples, toleranceSamples)
% Align each streaming sample to the nearest valid offline reference sample.
Alignment = struct();
Alignment.NUnmatched = 0;
Alignment.NExactMatches = 0;
Alignment.NToleranceMatches = 0;
Alignment.MaxSampleMismatch = NaN;

refValid = true(size(Ref.Power));
if isfield(Ref, 'IsValid') && numel(Ref.IsValid) == numel(Ref.Power)
    refValid = Ref.IsValid == true;
end
refValid = refValid & isfinite(Ref.Power);
refSamplesAll = local_ref_window_center_samples(Ref);
refSamples = refSamplesAll(refValid);
refPower = Ref.Power(refValid);

refAligned = NaN(size(streamSamples));
keep = false(size(streamSamples));
if isempty(refSamples)
    Alignment.NUnmatched = numel(streamSamples);
    return;
end

mismatches = NaN(size(streamSamples));
for i = 1:numel(streamSamples)
    if ~isfinite(streamSamples(i))
        Alignment.NUnmatched = Alignment.NUnmatched + 1;
        continue;
    end
    [sampleMismatch, idx] = min(abs(refSamples - streamSamples(i)));
    mismatches(i) = sampleMismatch;
    if sampleMismatch > toleranceSamples
        Alignment.NUnmatched = Alignment.NUnmatched + 1;
        continue;
    end

    refAligned(i) = refPower(idx);
    keep(i) = true;
    if sampleMismatch == 0
        Alignment.NExactMatches = Alignment.NExactMatches + 1;
    else
        Alignment.NToleranceMatches = Alignment.NToleranceMatches + 1;
    end
end

finiteMismatch = mismatches(isfinite(mismatches));
if ~isempty(finiteMismatch)
    Alignment.MaxSampleMismatch = max(finiteMismatch);
end
end

function samples = local_ref_window_center_samples(Ref)
% Prefer explicit window centers; fall back to SampleIndex for older tests/files.
if isfield(Ref, 'WindowCenterSample') && numel(Ref.WindowCenterSample) == numel(Ref.Power)
    samples = Ref.WindowCenterSample;
elseif isfield(Ref, 'SampleIndex') && numel(Ref.SampleIndex) == numel(Ref.Power)
    samples = Ref.SampleIndex;
else
    error('Ref must contain WindowCenterSample or SampleIndex aligned with Ref.Power.');
end
end

function strideMode = local_get_reference_stride_mode(RTConfig, Ref)
% Prefer config, then saved reference metadata, then dense fallback.
strideMode = 'dense';
if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'ReferenceStrideMode') && ...
        ~isempty(RTConfig.Validation.Step1.ReferenceStrideMode)
    strideMode = lower(char(RTConfig.Validation.Step1.ReferenceStrideMode));
elseif isfield(Ref, 'Metadata') && isfield(Ref.Metadata, 'ReferenceStrideMode') && ...
        ~isempty(Ref.Metadata.ReferenceStrideMode)
    strideMode = lower(char(Ref.Metadata.ReferenceStrideMode));
end
if ~ismember(strideMode, {'dense','step'})
    error('Unknown ReferenceStrideMode: %s', strideMode);
end
end

function stepSamples = local_get_reference_step_samples(RTConfig)
% The alignment tolerance is based on the active reference stride.
strideMode = 'dense';
if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'ReferenceStrideMode') && ...
        ~isempty(RTConfig.Validation.Step1.ReferenceStrideMode)
    strideMode = lower(char(RTConfig.Validation.Step1.ReferenceStrideMode));
end

if strcmp(strideMode, 'dense')
    stepSamples = 1;
    return;
elseif ~strcmp(strideMode, 'step')
    error('Unknown ReferenceStrideMode: %s', strideMode);
end

stepSamples = [];
if isfield(RTConfig.Validation.Step1, 'ReferenceStepSamples') && ...
        local_is_positive_scalar(RTConfig.Validation.Step1.ReferenceStepSamples)
    stepSamples = RTConfig.Validation.Step1.ReferenceStepSamples;
elseif isfield(RTConfig.Validation.Step1, 'StepSamples') && ...
        local_is_positive_scalar(RTConfig.Validation.Step1.StepSamples)
    stepSamples = RTConfig.Validation.Step1.StepSamples;
elseif isfield(RTConfig, 'ChunkSamples') && local_is_positive_scalar(RTConfig.ChunkSamples)
    stepSamples = RTConfig.ChunkSamples;
else
    stepSamples = 1;
end

stepSamples = round(stepSamples);
if stepSamples < 1
    error('RTConfig.Validation.Step1.ReferenceStepSamples must resolve to at least 1.');
end
end

function tf = local_is_positive_scalar(x)
% Check positive finite scalar stride values without throwing.
tf = isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1;
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
