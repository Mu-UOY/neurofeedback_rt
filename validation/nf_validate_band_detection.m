function Results = nf_validate_band_detection(Data, Ref, Measures, RTConfig, FFTResults)
% NF_VALIDATE_BAND_DETECTION Summarize target-band spectral diagnostics.
%
% USAGE:
%     Results = nf_validate_band_detection(Data, Ref, Measures, RTConfig)
%     Results = nf_validate_band_detection(Data, Ref, Measures, RTConfig, FFTResults)
%
% DESCRIPTION:
%     Reports official Step 1 target-band sanity diagnostics from the offline
%     reference, streaming Measures, and global PSD. This is a lightweight
%     validation check, not a statistical inference test.

%% ===== INITIALIZE RESULTS =====
% Keep the output schema stable across pass, warn, fail, and skipped states.
if nargin < 5
    FFTResults = [];
end

[enabled, searchBand, referenceBands] = local_band_detection_config(RTConfig);
Results = local_empty_results(RTConfig, Data, searchBand, referenceBands);

if ~enabled
    Results.Status = 'SKIPPED';
    Results.Message = 'Band detection disabled.';
    return;
end

%% ===== GET PSD SUMMARY =====
% Reuse Step 1 FFT output when present; otherwise compute a small fallback PSD.
[Frequency, Power, PowerMean] = local_get_psd(Data, RTConfig, FFTResults);
if isempty(Frequency) || isempty(PowerMean)
    Results.Status = 'FAIL';
    Results.Message = 'Could not compute PSD for band detection.';
    return;
end

%% ===== FIND SEARCH-BAND PEAK =====
% The strongest PSD peak is reported inside the configured search band.
searchMask = Frequency >= searchBand(1) & Frequency <= searchBand(2) & isfinite(PowerMean);
if any(searchMask)
    searchFreq = Frequency(searchMask);
    searchPower = PowerMean(searchMask);
    [Results.PeakPower, idxPeak] = max(searchPower);
    Results.PeakFrequency = searchFreq(idxPeak);
    Results.PeakInsideTargetBand = Results.PeakFrequency >= Results.TargetBand(1) && ...
        Results.PeakFrequency <= Results.TargetBand(2);
end

%% ===== SUMMARIZE TARGET AND REFERENCE BANDS =====
% Target trace prefers windowed power so nonconstant behavior is meaningful.
targetTrace = local_target_power_trace(Ref, FFTResults, Power, Frequency, RTConfig.TargetBand);
targetPsdPower = local_psd_band_power(Power, Frequency, RTConfig.TargetBand);
targetPsdMean = local_mean_finite(targetPsdPower);
Results.TargetPowerMean = local_mean_finite(targetTrace);
Results.TargetPowerMedian = local_median_finite(targetTrace);
Results.TargetPowerMax = local_max_finite(targetTrace);
Results.TargetPowerStd = local_std_finite(targetTrace);
Results.TargetPowerAllZero = local_all_zero(targetTrace);
Results.TargetPowerNonconstant = local_nonconstant(targetTrace);

Results.ReferenceBandPowerMean = NaN(1, size(referenceBands, 1));
Results.ReferenceBandPowerMedian = NaN(1, size(referenceBands, 1));
for iBand = 1:size(referenceBands, 1)
    bandPower = local_psd_band_power(Power, Frequency, referenceBands(iBand, :));
    Results.ReferenceBandPowerMean(iBand) = local_mean_finite(bandPower);
    Results.ReferenceBandPowerMedian(iBand) = local_median_finite(bandPower);
end

Results.BandRatios = targetPsdMean ./ Results.ReferenceBandPowerMean;

%% ===== SUMMARIZE REFERENCE AND STREAMING POWER =====
% These fields move temporary inspection checks into the saved Results struct.
refPower = local_ref_power(Ref);
Results.RefPowerMean = local_mean_finite(refPower);
Results.RefPowerStd = local_std_finite(refPower);
Results.RefPowerAllZero = local_all_zero(refPower);
Results.RefPowerNonconstant = local_nonconstant(refPower);

streamPower = local_stream_power(Measures);
Results.StreamPowerMean = local_mean_finite(streamPower);
Results.StreamPowerStd = local_std_finite(streamPower);
Results.StreamPowerAllZero = local_all_zero(streamPower);
Results.StreamPowerNonconstant = local_nonconstant(streamPower);

finiteValues = targetTrace(isfinite(targetTrace));
Results.NFiniteValues = numel(finiteValues);

%% ===== ASSIGN STATUS =====
% PASS is intentionally conservative: target power must exist, vary, and have
% spectral support from either the target peak or stronger target-band PSD.
targetAboveReference = local_target_above_reference( ...
    targetPsdMean, Results.ReferenceBandPowerMean, referenceBands, RTConfig.TargetBand);

Results.PassCriteria.FiniteTargetPower = Results.NFiniteValues > 0;
Results.PassCriteria.TargetPowerNonzero = ~Results.TargetPowerAllZero;
Results.PassCriteria.TargetPowerNonconstant = Results.TargetPowerNonconstant;
Results.PassCriteria.PeakInsideTargetBand = Results.PeakInsideTargetBand;
Results.PassCriteria.TargetAboveReferenceBand = targetAboveReference;
Results.PassCriteria.SpectralSupport = Results.PeakInsideTargetBand || targetAboveReference;

if Results.PassCriteria.FiniteTargetPower && ...
        Results.PassCriteria.TargetPowerNonzero && ...
        Results.PassCriteria.TargetPowerNonconstant && ...
        Results.PassCriteria.SpectralSupport
    Results.Status = 'PASS';
    Results.Message = 'Target-band power is finite, nonzero, nonconstant, and spectrally supported.';
elseif Results.PassCriteria.FiniteTargetPower && Results.PassCriteria.TargetPowerNonzero
    Results.Status = 'WARN';
    Results.Message = 'Target-band power exists, but spectral support or variability is limited.';
else
    Results.Status = 'FAIL';
    Results.Message = 'Target-band power diagnostics failed.';
end

end

function Results = local_empty_results(RTConfig, Data, searchBand, referenceBands)
% Create all required output fields with conservative defaults.
Results = struct();
Results.Status = 'FAIL';
Results.Message = '';
Results.TargetBand = RTConfig.TargetBand;
Results.SearchBand = searchBand;
Results.PeakFrequency = NaN;
Results.PeakPower = NaN;
Results.PeakInsideTargetBand = false;

Results.TargetPowerMean = NaN;
Results.TargetPowerMedian = NaN;
Results.TargetPowerMax = NaN;
Results.TargetPowerStd = NaN;
Results.TargetPowerAllZero = true;
Results.TargetPowerNonconstant = false;

Results.ReferenceBands = referenceBands;
Results.ReferenceBandPowerMean = NaN(1, size(referenceBands, 1));
Results.ReferenceBandPowerMedian = NaN(1, size(referenceBands, 1));
Results.BandRatios = NaN(1, size(referenceBands, 1));

Results.RefPowerMean = NaN;
Results.RefPowerStd = NaN;
Results.RefPowerAllZero = true;
Results.RefPowerNonconstant = false;

Results.StreamPowerMean = NaN;
Results.StreamPowerStd = NaN;
Results.StreamPowerAllZero = true;
Results.StreamPowerNonconstant = false;

Results.NFiniteValues = 0;
Results.PassCriteria = struct();
Results.PassCriteria.FiniteTargetPower = false;
Results.PassCriteria.TargetPowerNonzero = false;
Results.PassCriteria.TargetPowerNonconstant = false;
Results.PassCriteria.PeakInsideTargetBand = false;
Results.PassCriteria.TargetAboveReferenceBand = false;
Results.PassCriteria.SpectralSupport = false;

Results.Fs = Data.Fs;
Results.NChannels = size(Data.X, 1);
Results.NSamples = size(Data.X, 2);
end

function [enabled, searchBand, referenceBands] = local_band_detection_config(RTConfig)
% Read band-detection config with default Step 1B values.
enabled = true;
searchBand = [1 60];
referenceBands = [4 8; 8 12; 13 30; 30 59];

if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'BandDetection')
    cfg = RTConfig.Validation.Step1.BandDetection;
    if isfield(cfg, 'Enable') && ~isempty(cfg.Enable)
        enabled = logical(cfg.Enable);
    end
    if isfield(cfg, 'SearchBand') && isnumeric(cfg.SearchBand) && numel(cfg.SearchBand) == 2
        searchBand = double(reshape(cfg.SearchBand, 1, []));
    end
    if isfield(cfg, 'ReferenceBands') && isnumeric(cfg.ReferenceBands) && size(cfg.ReferenceBands, 2) == 2
        referenceBands = double(cfg.ReferenceBands);
    end
end
end

function [Frequency, Power, PowerMean] = local_get_psd(Data, RTConfig, FFTResults)
% Prefer already-computed Step 1 FFT output.
Frequency = [];
Power = [];
PowerMean = [];

if isstruct(FFTResults) && isfield(FFTResults, 'GlobalPSD') && ...
        isfield(FFTResults.GlobalPSD, 'Frequency') && isfield(FFTResults.GlobalPSD, 'Power')
    Frequency = reshape(FFTResults.GlobalPSD.Frequency, 1, []);
    Power = FFTResults.GlobalPSD.Power;
    if isfield(FFTResults.GlobalPSD, 'PowerMean')
        PowerMean = reshape(FFTResults.GlobalPSD.PowerMean, 1, []);
    else
        PowerMean = mean(Power, 1);
    end
    return;
end

X = double(Data.X);
X = bsxfun(@minus, X, mean(X, 2));
nSamples = size(X, 2);
nfft = max(nSamples, 2 ^ nextpow2(nSamples));
Y = fft(X, nfft, 2);
nFreq = floor(nfft ./ 2) + 1;
Power = abs(Y(:, 1:nFreq)) .^ 2 ./ (RTConfig.Fs .* nSamples);
if nFreq > 2
    Power(:, 2:(end - 1)) = 2 .* Power(:, 2:(end - 1));
end
Frequency = (0:(nFreq - 1)) .* RTConfig.Fs ./ nfft;
PowerMean = mean(Power, 1);
end

function targetTrace = local_target_power_trace(Ref, FFTResults, Power, Frequency, targetBand)
% Prefer windowed target-band traces over global PSD per-signal summaries.
targetTrace = local_ref_power(Ref);
if ~isempty(targetTrace)
    return;
end

if isstruct(FFTResults) && isfield(FFTResults, 'WindowedFFT') && ...
        isfield(FFTResults.WindowedFFT, 'Power')
    targetTrace = FFTResults.WindowedFFT.Power;
    return;
end

targetTrace = local_psd_band_power(Power, Frequency, targetBand);
end

function powerValues = local_ref_power(Ref)
% Extract valid offline reference power.
powerValues = [];
if isempty(Ref) || ~isstruct(Ref) || ~isfield(Ref, 'Power')
    return;
end
valid = true(size(Ref.Power));
if isfield(Ref, 'IsValid') && numel(Ref.IsValid) == numel(Ref.Power)
    valid = Ref.IsValid == true;
end
powerValues = Ref.Power(valid);
end

function powerValues = local_stream_power(Measures)
% Extract valid streaming power.
powerValues = [];
if isempty(Measures)
    return;
end
valid = [Measures.IsValid] == true;
if any(valid)
    powerValues = [Measures(valid).Power];
end
end

function bandPower = local_psd_band_power(Power, Frequency, band)
% Integrate PSD over a frequency band for each signal.
mask = Frequency >= band(1) & Frequency <= band(2);
if any(mask)
    bandPower = sum(Power(:, mask), 2) .* local_frequency_step(Frequency);
else
    bandPower = NaN(size(Power, 1), 1);
end
end

function tf = local_target_above_reference(targetMean, referenceMeans, referenceBands, targetBand)
% Require target power to exceed every non-overlapping reference band.
tf = false;
if ~isfinite(targetMean) || isempty(referenceMeans)
    return;
end
referenceMeans = reshape(referenceMeans, 1, []);
overlap = reshape(referenceBands(:, 1) < targetBand(2) & referenceBands(:, 2) > targetBand(1), 1, []);
comparison = referenceMeans(~overlap & isfinite(referenceMeans));
if isempty(comparison)
    comparison = referenceMeans(isfinite(referenceMeans));
end
if isempty(comparison)
    return;
end
tf = targetMean > max(comparison);
end

function m = local_mean_finite(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = mean(x);
end
end

function m = local_median_finite(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = median(x);
end
end

function m = local_max_finite(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = max(x);
end
end

function s = local_std_finite(x)
x = x(isfinite(x));
if numel(x) < 2
    s = NaN;
else
    s = std(x);
end
end

function tf = local_all_zero(x)
% Treat empty/nonfinite traces as all-zero for conservative diagnostics.
x = x(isfinite(x));
if isempty(x)
    tf = true;
else
    scale = max(abs(x));
    if scale == 0
        tf = true;
    else
        tf = all(abs(x) <= 100 .* eps(scale));
    end
end
end

function tf = local_nonconstant(x)
% Detect meaningful finite variation without overfitting to exact equality.
x = x(isfinite(x));
if numel(x) < 2
    tf = false;
else
    scale = max(abs(x));
    if scale == 0
        tf = false;
        return;
    end
    tf = (max(x) - min(x)) > 100 .* eps(scale);
end
end

function df = local_frequency_step(Frequency)
if numel(Frequency) > 1
    df = median(diff(Frequency));
else
    df = 1;
end
end
