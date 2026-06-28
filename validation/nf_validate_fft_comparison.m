function Results = nf_validate_fft_comparison(Data, Ref, RTConfig)
% NF_VALIDATE_FFT_COMPARISON Run offline FFT/Welch spectral sanity checks.
%
% USAGE:  Results = nf_validate_fft_comparison(Data, Ref, RTConfig)
%
% DESCRIPTION:
%     Computes a global PSD, target/reference band powers, and a windowed
%     FFT target-band trace. This is an offline spectral sanity check, not
%     a claim of successful IPS theta neurofeedback.

%% ===== INITIALIZE RESULT STRUCT =====
% The output schema is stable across pwelch and fallback FFT modes.
Results = struct();
Results.Status = 'FAIL';
Results.Message = '';
Results.GlobalPSD = struct();
Results.BandPower = struct();
Results.WindowedFFT = struct();
Results.CompareToRef = struct();
Results.WindowWarning = '';
Results.Metadata = struct();

%% ===== CHECK DATA =====
% Step 1 spectral validation works directly from Data and RTConfig.
if ~isstruct(Data) || ~isfield(Data, 'X') || ~isnumeric(Data.X) || ndims(Data.X) ~= 2
    Results.Message = 'Data.X must be a numeric [nChannels x nSamples] matrix.';
    return;
end
if ~isfield(Data, 'Fs') || ~isfinite(Data.Fs) || abs(Data.Fs - RTConfig.Fs) > 1e-9
    Results.Message = 'Data.Fs is missing or does not match RTConfig.Fs.';
    return;
end

%% ===== APPLY SPATIAL PROJECTION =====
% Use the same first-version projection contract as the rest of the pipeline.
localConfig = RTConfig;
if isempty(localConfig.Spatial.NChannels)
    localConfig.Spatial.NChannels = size(Data.X, 1);
end
CombinedMatrix = nf_build_combined_matrix(localConfig);
X = CombinedMatrix * Data.X;

%% ===== PREPARE SIGNAL =====
% Demeaning removes DC before PSD and windowed FFT bandpower estimates.
cfg = local_step1_fft_config(RTConfig);
if cfg.DemeanBeforeFFT
    X = bsxfun(@minus, X, mean(X, 2));
end

[W, S] = local_step1_window_settings(RTConfig);
if W > size(X, 2)
    Results.Message = 'Step 1 FFT window is longer than the dataset.';
    return;
end

cycles = W ./ RTConfig.Fs .* RTConfig.TargetBand(1);
if cycles < local_min_cycles(RTConfig)
    Results.WindowWarning = sprintf('Window contains %.3g cycles at %.3g Hz; configured minimum is %.3g.', ...
        cycles, RTConfig.TargetBand(1), local_min_cycles(RTConfig));
end

%% ===== COMPUTE GLOBAL PSD =====
% Prefer Welch when available; otherwise use a one-sided periodogram.
if cfg.UseWelchIfAvailable && local_function_exists('pwelch')
    Results.GlobalPSD = local_global_pwelch(X, RTConfig, W, cfg);
else
    Results.GlobalPSD = local_global_fft_periodogram(X, RTConfig, cfg);
end

%% ===== COMPUTE BAND POWERS =====
% Store target and configured reference bands with explicit field names.
Results.BandPower.Target = local_bandpower_struct( ...
    Results.GlobalPSD.Power, Results.GlobalPSD.Frequency, RTConfig.TargetBand);

refBands = cfg.ReferenceBands;
Results.BandPower.Reference = repmat(struct( ...
    'Band', [], 'PowerPerSignal', [], 'PowerMean', NaN, 'PowerMedian', NaN), 1, size(refBands, 1));
for iBand = 1:size(refBands, 1)
    Results.BandPower.Reference(iBand) = local_bandpower_struct( ...
        Results.GlobalPSD.Power, Results.GlobalPSD.Frequency, refBands(iBand, :));
end

%% ===== COMPUTE WINDOWED FFT BANDPOWER =====
% Windowed target-band power provides an independent trace for comparison.
sampleIndices = local_data_sample_indices(Data);
windowStarts = local_window_starts_from_ref_or_config(Ref, sampleIndices, W, S);
Results.WindowedFFT = local_windowed_fft_bandpower(X, sampleIndices, windowStarts, RTConfig, cfg);

%% ===== COMPARE WINDOWED FFT TRACE TO REF =====
% Z-scoring avoids over-interpreting raw amplitude differences.
Results.CompareToRef = local_compare_to_ref(Ref, Results.WindowedFFT);

%% ===== SET STATUS =====
% PASS means the computation succeeded and target-band power is finite.
targetFinite = any(isfinite(Results.BandPower.Target.PowerPerSignal));
if ~targetFinite || any(~isfinite(Results.GlobalPSD.PowerMean))
    Results.Status = 'FAIL';
    Results.Message = 'FFT comparison produced nonfinite core output.';
elseif ~isempty(Results.WindowWarning) || Results.CompareToRef.NCompared < 2
    Results.Status = 'WARN';
    Results.Message = 'FFT comparison completed with limited window/comparison support.';
else
    Results.Status = 'PASS';
    Results.Message = 'FFT comparison completed.';
end

Results.Metadata.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Results.Metadata.NSignals = size(X, 1);
Results.Metadata.NSamples = size(X, 2);

end

function cfg = local_step1_fft_config(RTConfig)
cfg = struct();
cfg.UseWelchIfAvailable = true;
cfg.DemeanBeforeFFT = true;
cfg.Taper = 'hann';
cfg.NFFT = [];
cfg.ReferenceBands = [4 8; 8 12; 13 30];

if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'FFT')
    userCfg = RTConfig.Validation.Step1.FFT;
    fields = fieldnames(cfg);
    for i = 1:numel(fields)
        if isfield(userCfg, fields{i})
            cfg.(fields{i}) = userCfg.(fields{i});
        end
    end
end
end

function [W, S] = local_step1_window_settings(RTConfig)
W = RTConfig.PowerWindowSamples;
S = RTConfig.ChunkSamples;
if isfield(RTConfig.Validation, 'Step1')
    if isfield(RTConfig.Validation.Step1, 'WindowSamples') && ~isempty(RTConfig.Validation.Step1.WindowSamples)
        W = RTConfig.Validation.Step1.WindowSamples;
    end
    if isfield(RTConfig.Validation.Step1, 'StepSamples') && ~isempty(RTConfig.Validation.Step1.StepSamples)
        S = RTConfig.Validation.Step1.StepSamples;
    end
end
W = max(1, round(W));
S = max(1, round(S));
end

function minCycles = local_min_cycles(RTConfig)
minCycles = 3;
if isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'MinCyclesAtLowFreq') && ...
        ~isempty(RTConfig.Validation.Step1.MinCyclesAtLowFreq)
    minCycles = RTConfig.Validation.Step1.MinCyclesAtLowFreq;
end
end

function tf = local_function_exists(functionName)
tf = exist(functionName, 'file') ~= 0 || exist(functionName, 'builtin') ~= 0;
end

function GlobalPSD = local_global_pwelch(X, RTConfig, W, cfg)
windowSamples = min(W, size(X, 2));
nfft = local_nfft(cfg.NFFT, windowSamples);
taper = local_taper(cfg.Taper, windowSamples);
overlap = floor(windowSamples / 2);

Power = [];
Frequency = [];
for iSignal = 1:size(X, 1)
    [pxx, freq] = pwelch(X(iSignal, :)', taper(:), overlap, nfft, RTConfig.Fs);
    Power(iSignal, :) = reshape(pxx, 1, []); %#ok<AGROW>
    Frequency = reshape(freq, 1, []);
end

GlobalPSD = local_global_schema('pwelch', Frequency, Power, RTConfig.Fs, nfft, ...
    windowSamples, cfg.DemeanBeforeFFT, cfg.Taper);
end

function GlobalPSD = local_global_fft_periodogram(X, RTConfig, cfg)
windowSamples = size(X, 2);
nfft = local_nfft(cfg.NFFT, windowSamples);
taper = local_taper(cfg.Taper, windowSamples);
Xt = bsxfun(@times, X, reshape(taper, 1, []));

Y = fft(Xt, nfft, 2);
nFreq = floor(nfft / 2) + 1;
Power = abs(Y(:, 1:nFreq)) .^ 2 ./ (RTConfig.Fs .* sum(taper .^ 2));
if nFreq > 2
    Power(:, 2:(end - 1)) = 2 .* Power(:, 2:(end - 1));
end
Frequency = (0:(nFreq - 1)) .* RTConfig.Fs ./ nfft;

GlobalPSD = local_global_schema('fft_periodogram', Frequency, Power, RTConfig.Fs, nfft, ...
    windowSamples, cfg.DemeanBeforeFFT, cfg.Taper);
end

function GlobalPSD = local_global_schema(method, Frequency, Power, Fs, nfft, windowSamples, demeaned, taperName)
GlobalPSD = struct();
GlobalPSD.Method = method;
GlobalPSD.Frequency = Frequency;
GlobalPSD.Power = Power;
GlobalPSD.PowerMean = mean(Power, 1);
GlobalPSD.Fs = Fs;
GlobalPSD.NFFT = nfft;
GlobalPSD.WindowSamples = windowSamples;
GlobalPSD.Demeaned = logical(demeaned);
GlobalPSD.Taper = taperName;
end

function nfft = local_nfft(configuredNFFT, windowSamples)
if isempty(configuredNFFT)
    nfft = max(windowSamples, 2 ^ nextpow2(windowSamples));
else
    nfft = max(windowSamples, round(configuredNFFT));
end
end

function taper = local_taper(taperName, nSamples)
switch lower(char(taperName))
    case 'hann'
        if local_function_exists('hann')
            taper = hann(nSamples)';
        elseif local_function_exists('hanning')
            taper = hanning(nSamples)';
        else
            n = 0:(nSamples - 1);
            taper = 0.5 - 0.5 .* cos(2 .* pi .* n ./ max(1, nSamples - 1));
        end
    case {'rect','rectangular','none'}
        taper = ones(1, nSamples);
    otherwise
        warning('Unknown taper "%s"; using rectangular taper.', char(taperName));
        taper = ones(1, nSamples);
end
end

function Band = local_bandpower_struct(Power, Frequency, band)
mask = Frequency >= band(1) & Frequency <= band(2);
if any(mask)
    df = local_frequency_step(Frequency);
    powerPerSignal = sum(Power(:, mask), 2) .* df;
else
    powerPerSignal = NaN(size(Power, 1), 1);
end

Band = struct();
Band.Band = band;
Band.PowerPerSignal = powerPerSignal;
Band.PowerMean = local_mean_finite(powerPerSignal);
Band.PowerMedian = local_median_finite(powerPerSignal);
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

function df = local_frequency_step(Frequency)
if numel(Frequency) > 1
    df = median(diff(Frequency));
else
    df = 1;
end
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

function windowStarts = local_window_starts_from_ref_or_config(Ref, sampleIndices, W, S)
nSamples = numel(sampleIndices);
defaultStarts = 1:S:(nSamples - W + 1);
windowStarts = defaultStarts;

if nargin < 1 || isempty(Ref) || ~isstruct(Ref) || ~isfield(Ref, 'WindowStartSample')
    return;
end

refStartsAcq = Ref.WindowStartSample(isfinite(Ref.WindowStartSample));
if isempty(refStartsAcq)
    return;
end

mappedStarts = NaN(size(refStartsAcq));
for i = 1:numel(refStartsAcq)
    idx = find(sampleIndices == refStartsAcq(i), 1, 'first');
    if ~isempty(idx)
        mappedStarts(i) = idx;
    end
end

mappedStarts = mappedStarts(isfinite(mappedStarts));
mappedStarts = mappedStarts(mappedStarts >= 1 & (mappedStarts + W - 1) <= nSamples);

if ~isempty(mappedStarts)
    windowStarts = mappedStarts;
end
end

function WindowedFFT = local_windowed_fft_bandpower(X, sampleIndices, windowStarts, RTConfig, cfg)
W = local_step1_window_settings(RTConfig);
if numel(W) > 1
    W = W(1);
end
nSignals = size(X, 1);
nWindows = numel(windowStarts);

WindowedFFT = struct();
WindowedFFT.Power = NaN(1, nWindows);
WindowedFFT.PowerPerSignal = NaN(nSignals, nWindows);
WindowedFFT.SampleIndex = NaN(1, nWindows);
WindowedFFT.Time = NaN(1, nWindows);
WindowedFFT.WindowStartSample = NaN(1, nWindows);
WindowedFFT.WindowEndSample = NaN(1, nWindows);
WindowedFFT.WindowCenterSample = NaN(1, nWindows);

nfft = local_nfft(cfg.NFFT, W);
taper = local_taper(cfg.Taper, W);
freq = (0:floor(nfft / 2)) .* RTConfig.Fs ./ nfft;
bandMask = freq >= RTConfig.TargetBand(1) & freq <= RTConfig.TargetBand(2);
df = local_frequency_step(freq);

for iWindow = 1:nWindows
    startPos = windowStarts(iWindow);
    endPos = startPos + W - 1;
    centerPos = startPos + floor(W / 2);
    xwin = X(:, startPos:endPos);
    xwin = bsxfun(@times, xwin, reshape(taper, 1, []));
    Y = fft(xwin, nfft, 2);
    P = abs(Y(:, 1:numel(freq))) .^ 2 ./ (RTConfig.Fs .* sum(taper .^ 2));
    if size(P, 2) > 2
        P(:, 2:(end - 1)) = 2 .* P(:, 2:(end - 1));
    end

    WindowedFFT.PowerPerSignal(:, iWindow) = sum(P(:, bandMask), 2) .* df;
    WindowedFFT.Power(iWindow) = mean(WindowedFFT.PowerPerSignal(:, iWindow));
    WindowedFFT.WindowStartSample(iWindow) = sampleIndices(startPos);
    WindowedFFT.WindowEndSample(iWindow) = sampleIndices(endPos);
    WindowedFFT.WindowCenterSample(iWindow) = sampleIndices(centerPos);
    WindowedFFT.SampleIndex(iWindow) = WindowedFFT.WindowCenterSample(iWindow);
    WindowedFFT.Time(iWindow) = WindowedFFT.SampleIndex(iWindow) ./ RTConfig.Fs;
end
end

function Compare = local_compare_to_ref(Ref, WindowedFFT)
Compare = struct();
Compare.Correlation = NaN;
Compare.RMSE = NaN;
Compare.NCompared = 0;

if isempty(Ref) || ~isstruct(Ref) || ~isfield(Ref, 'Power') || ~isfield(Ref, 'SampleIndex')
    return;
end
if isempty(WindowedFFT.Power) || isempty(Ref.Power)
    return;
end

refValid = true(size(Ref.Power));
if isfield(Ref, 'IsValid') && numel(Ref.IsValid) == numel(Ref.Power)
    refValid = Ref.IsValid == true;
end

refSamples = Ref.SampleIndex(refValid);
refPower = Ref.Power(refValid);
streamSamples = WindowedFFT.SampleIndex;
streamPower = WindowedFFT.Power;

alignedRef = NaN(size(streamPower));
for i = 1:numel(streamSamples)
    [~, idx] = min(abs(refSamples - streamSamples(i)));
    if ~isempty(idx)
        alignedRef(i) = refPower(idx);
    end
end

keep = isfinite(alignedRef) & isfinite(streamPower);
Compare.NCompared = nnz(keep);
if Compare.NCompared < 2
    return;
end

zRef = local_zscore(alignedRef(keep));
zFFT = local_zscore(streamPower(keep));
Compare.Correlation = local_corr(zRef, zFFT);
Compare.RMSE = sqrt(mean((zRef - zFFT) .^ 2));
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
