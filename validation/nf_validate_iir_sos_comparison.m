function Results = nf_validate_iir_sos_comparison(Data, Ref, RTConfig) %#ok<INUSD>
% NF_VALIDATE_IIR_SOS_COMPARISON Compare offline IIR/SOS and Brainstorm power.
%
% USAGE:  Results = nf_validate_iir_sos_comparison(Data, Ref, RTConfig)
%
% DESCRIPTION:
%     Applies the configured spatial projection, computes an offline IIR/SOS
%     target-band power trace, optionally computes a Brainstorm-style trace,
%     and compares their windowed power trends.
%
%     Ref is accepted for API consistency with other validation functions.
%     This Step 1A filter comparison recomputes its own offline IIR and
%     Brainstorm-style references from Data, so Ref is intentionally unused.

%% ===== INITIALIZE RESULT STRUCT =====
% Keep all expected top-level fields present even for skipped comparisons.
Results = struct();
Results.Status = 'FAIL';
Results.Message = '';
Results.IIRInfo = struct();
Results.BrainstormInfo = struct();
Results.IIRRef = struct();
Results.BrainstormRef = struct();
Results.Compare = local_empty_compare();
Results.Metadata = struct();

%% ===== CHECK DATA =====
% The comparison operates on full offline data, not streaming Measures.
if ~isstruct(Data) || ~isfield(Data, 'X') || ~isnumeric(Data.X) || ndims(Data.X) ~= 2
    Results.Message = 'Data.X must be a numeric [nChannels x nSamples] matrix.';
    return;
end
if ~isfield(Data, 'Fs') || ~isfinite(Data.Fs) || abs(Data.Fs - RTConfig.Fs) > 1e-9
    Results.Message = 'Data.Fs is missing or does not match RTConfig.Fs.';
    return;
end

%% ===== APPLY SPATIAL PROJECTION =====
% Both filters must see the same post-spatial signal.
localConfig = RTConfig;
if isempty(localConfig.Spatial.NChannels)
    localConfig.Spatial.NChannels = size(Data.X, 1);
end
CombinedMatrix = nf_build_combined_matrix(localConfig);
X = CombinedMatrix * Data.X;
sampleIndices = local_data_sample_indices(Data);

%% ===== COMPUTE OFFLINE IIR/SOS REFERENCE =====
% This helper is also used by nf_make_offline_reference to avoid drift.
[Xiir, IIRInfo] = nf_apply_offline_iir_sos(X, RTConfig);
IIRRef = nf_compute_offline_window_power(Xiir, sampleIndices, RTConfig, 'iir_sos_offline');

Results.IIRInfo = IIRInfo;
Results.IIRRef = IIRRef;

%% ===== COMPUTE BRAINSTORM-STYLE REFERENCE =====
% Missing Brainstorm assets are a clean skip unless explicitly required.
[Xbst, BSTInfo] = nf_apply_offline_brainstorm_bandpass(X, RTConfig);
Results.BrainstormInfo = BSTInfo;

if isfield(BSTInfo, 'Status') && strcmp(BSTInfo.Status, 'SKIPPED')
    Results.Status = 'SKIPPED';
    Results.Message = BSTInfo.Message;
    Results.Metadata.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    return;
end

if isempty(Xbst) || ~isequal(size(Xbst), size(X))
    Results.Status = 'FAIL';
    Results.Message = 'Brainstorm-style filtered output is empty or dimensionally invalid.';
    return;
end

BSTRef = nf_compute_offline_window_power(Xbst, sampleIndices, RTConfig, 'brainstorm_offline');
Results.BrainstormRef = BSTRef;

%% ===== COMPARE POWER TRACES =====
% Raw amplitudes can differ; z-scored trend agreement is the main sanity metric.
Results.Compare = local_compare_refs(IIRRef, BSTRef, RTConfig);

if Results.Compare.NCompared < 2 || ~isfinite(Results.Compare.ZCorrelation)
    Results.Status = 'FAIL';
    Results.Message = 'IIR/SOS versus Brainstorm comparison produced insufficient finite windows.';
elseif Results.Compare.ZCorrelation >= 0.90
    Results.Status = 'PASS';
    Results.Message = 'IIR/SOS and Brainstorm-style windowed power trends agree.';
else
    Results.Status = 'WARN';
    Results.Message = 'IIR/SOS and Brainstorm-style trends differ; inspect filter gain/phase/edge handling.';
end

Results.Metadata.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Results.Metadata.NSignals = size(X, 1);
Results.Metadata.NSamples = size(X, 2);

end

function Compare = local_empty_compare()
Compare = struct();
Compare.RawCorrelation = NaN;
Compare.ZCorrelation = NaN;
Compare.RawRMSE = NaN;
Compare.ZRMSE = NaN;
Compare.MeanPowerRatio = NaN;
Compare.MedianPowerRatio = NaN;
Compare.MaxAbsZDiff = NaN;
Compare.NCompared = 0;
Compare.BestLagSamples = NaN;
Compare.XCorrPeak = NaN;
Compare.SignConvention = 'Positive lag means IIR trace is delayed relative to Brainstorm trace.';
end

function sampleIndices = local_data_sample_indices(Data)
nSamples = size(Data.X, 2);
if isfield(Data, 'Metadata') && isfield(Data.Metadata, 'SampleRange') && ...
        numel(Data.Metadata.SampleRange) == 2
    startSample = Data.Metadata.SampleRange(1);
    stopSample = Data.Metadata.SampleRange(2);
    if stopSample - startSample + 1 == nSamples
        sampleIndices = startSample:stopSample;
        return;
    end
end
sampleIndices = 1:nSamples;
end

function Compare = local_compare_refs(IIRRef, BSTRef, RTConfig)
Compare = local_empty_compare();

[iirPower, bstPower, samples] = local_align_power(IIRRef, BSTRef);
keep = isfinite(iirPower) & isfinite(bstPower);
iirPower = iirPower(keep);
bstPower = bstPower(keep);
samples = samples(keep);

Compare.NCompared = numel(iirPower);
if Compare.NCompared < 2
    return;
end

ziir = local_zscore(iirPower);
zbst = local_zscore(bstPower);

Compare.RawCorrelation = local_corr(iirPower, bstPower);
Compare.ZCorrelation = local_corr(ziir, zbst);
Compare.RawRMSE = sqrt(mean((iirPower - bstPower) .^ 2));
Compare.ZRMSE = sqrt(mean((ziir - zbst) .^ 2));
Compare.MeanPowerRatio = mean(iirPower) ./ mean(bstPower);
Compare.MedianPowerRatio = median(iirPower) ./ median(bstPower);
Compare.MaxAbsZDiff = max(abs(ziir - zbst));

if numel(samples) > 1
    sampleStep = median(diff(samples));
else
    sampleStep = RTConfig.ChunkSamples;
end
if ~isfinite(sampleStep) || sampleStep <= 0
    sampleStep = RTConfig.ChunkSamples;
end

maxLagSteps = min(numel(ziir) - 2, ceil(RTConfig.Validation.MaxLagSamples ./ sampleStep));
if maxLagSteps >= 1
    [bestLagSteps, peak] = local_lag_corr(zbst, ziir, maxLagSteps);
    Compare.BestLagSamples = bestLagSteps .* sampleStep;
    Compare.XCorrPeak = peak;
end
end

function [iirPower, bstPower, samples] = local_align_power(IIRRef, BSTRef)
iirPower = IIRRef.Power;
samples = IIRRef.SampleIndex;
bstPower = NaN(size(iirPower));

bstValid = true(size(BSTRef.Power));
if isfield(BSTRef, 'IsValid') && numel(BSTRef.IsValid) == numel(BSTRef.Power)
    bstValid = BSTRef.IsValid == true;
end
bstSamples = BSTRef.SampleIndex(bstValid);
bstValues = BSTRef.Power(bstValid);

for i = 1:numel(samples)
    [~, idx] = min(abs(bstSamples - samples(i)));
    if ~isempty(idx)
        bstPower(i) = bstValues(idx);
    end
end
end

function z = local_zscore(x)
x = x(:)';
sigma = std(x);
if ~isfinite(sigma) || sigma == 0
    z = NaN(size(x));
else
    z = (x - mean(x)) ./ sigma;
end
end

function r = local_corr(x, y)
x = x(:);
y = y(:);
if numel(x) < 2 || std(x) == 0 || std(y) == 0
    r = NaN;
    return;
end
C = corrcoef(x, y);
r = C(1, 2);
end

function [bestLag, peak] = local_lag_corr(referenceTrace, delayedTrace, maxLag)
lags = -maxLag:maxLag;
scores = NaN(size(lags));

for iLag = 1:numel(lags)
    lag = lags(iLag);
    if lag >= 0
        x = referenceTrace(1:(end - lag));
        y = delayedTrace((1 + lag):end);
    else
        d = -lag;
        x = referenceTrace((1 + d):end);
        y = delayedTrace(1:(end - d));
    end
    scores(iLag) = local_corr(x, y);
end

[peak, idx] = max(scores);
bestLag = lags(idx);
end
