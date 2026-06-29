function ThetaRecovery = nf_validate_theta_recovery(Results, Ref, Measures, BlockInfo, RTConfig) %#ok<INUSD>
% NF_VALIDATE_THETA_RECOVERY Validate block-wise theta recovery/control.
%
% USAGE:  ThetaRecovery = nf_validate_theta_recovery(Results, Ref, Measures, BlockInfo, RTConfig)
%
% DESCRIPTION:
%     Uses BlockInfo labels and sample boundaries to evaluate whether
%     theta_on blocks show stronger target-band feedback values than off
%     blocks, and whether wrong_band controls avoid false theta positives.

%% ===== INITIALIZE OUTPUT =====
% Fail closed until a requested validation can be computed.
if nargin < 5 || isempty(RTConfig)
    RTConfig = struct();
end
if nargin < 4
    BlockInfo = [];
end
if nargin < 3
    Measures = [];
end
if nargin < 1
    Results = [];
end

ThetaRecovery = local_empty_result(RTConfig, Results, BlockInfo);
messages = {};

%% ===== CHECK INPUTS =====
% BlockInfo is required for block-specific validation.
if isempty(BlockInfo) || ~isstruct(BlockInfo) || ...
        ~isfield(BlockInfo, 'Labels') || ~isfield(BlockInfo, 'StartSample') || ...
        ~isfield(BlockInfo, 'EndSample')
    ThetaRecovery.Messages = {'BlockInfo with Labels/StartSample/EndSample is required.'};
    return;
end
if isempty(Measures) || ~isstruct(Measures)
    ThetaRecovery.Messages = {'Measures must be a nonempty struct array.'};
    return;
end

labels = local_labels(BlockInfo);
nBlocks = numel(labels);
if nBlocks == 0
    ThetaRecovery.Messages = {'BlockInfo.Labels is empty.'};
    return;
end

%% ===== EXTRACT MEASURE TRACES =====
% Prefer z-score traces, then fall back to Power.
[metricValues, metricName] = local_preferred_metric(Measures);
powerValues = local_numeric_vector(Measures, 'Power');
sampleIndex = local_measure_samples(Measures);
isValid = local_valid_flags(Measures);

if all(~isfinite(metricValues)) || all(~isfinite(sampleIndex))
    ThetaRecovery.Messages = {'No finite measure metric or sample index was available.'};
    return;
end
messages{end + 1} = sprintf('Recovery metric: %s.', metricName); %#ok<AGROW>

%% ===== COMPUTE BLOCK METRICS =====
% Each block uses only valid finite measures whose sample falls inside bounds.
meanMetric = NaN(1, nBlocks);
meanPower = NaN(1, nBlocks);
nValid = zeros(1, nBlocks);
for iBlock = 1:nBlocks
    idx = sampleIndex >= BlockInfo.StartSample(iBlock) & ...
        sampleIndex <= BlockInfo.EndSample(iBlock) & isValid;
    metricKeep = idx & isfinite(metricValues);
    powerKeep = idx & isfinite(powerValues);
    meanMetric(iBlock) = local_mean_finite(metricValues(metricKeep));
    meanPower(iBlock) = local_mean_finite(powerValues(powerKeep));
    nValid(iBlock) = nnz(metricKeep | powerKeep);
end

ThetaRecovery.MeanZByBlock = struct('Labels', {labels}, 'Values', meanMetric);
ThetaRecovery.MeanPowerByBlock = struct('Labels', {labels}, 'Values', meanPower);
ThetaRecovery.NValidByBlock = struct('Labels', {labels}, 'Values', nValid);

%% ===== EVALUATE THETA RECOVERY =====
% theta_on must exceed off/baseline comparison blocks by the configured margin.
hasThetaOn = any(strcmp(labels, 'theta_on'));
hasWrongBand = any(strcmp(labels, 'wrong_band'));
checks = [];

if hasThetaOn
    thetaOn = strcmp(labels, 'theta_on');
    thetaOff = local_off_block_mask(labels);
    ThetaRecovery.MeanZThetaOn = local_mean_finite(meanMetric(thetaOn));
    ThetaRecovery.MeanZThetaOff = local_mean_finite(meanMetric(thetaOff));
    ThetaRecovery.ThetaOnMinusThetaOff = ThetaRecovery.MeanZThetaOn - ThetaRecovery.MeanZThetaOff;

    if ~isfinite(ThetaRecovery.ThetaOnMinusThetaOff)
        checks(end + 1) = false; %#ok<AGROW>
        messages{end + 1} = 'Theta recovery could not be computed from finite theta_on/off metrics.'; %#ok<AGROW>
    elseif ThetaRecovery.ThetaOnMinusThetaOff >= local_min_theta_delta(RTConfig)
        checks(end + 1) = true; %#ok<AGROW>
        messages{end + 1} = 'Theta recovery passed.'; %#ok<AGROW>
    else
        checks(end + 1) = false; %#ok<AGROW>
        messages{end + 1} = 'Theta recovery failed: theta_on did not exceed off blocks enough.'; %#ok<AGROW>
    end
end

%% ===== EVALUATE WRONG-BAND CONTROL =====
% wrong_band blocks should not exceed the false-positive z threshold.
if hasWrongBand
    wrongBand = strcmp(labels, 'wrong_band');
    ThetaRecovery.MeanZWrongBand = local_mean_finite(meanMetric(wrongBand));
    if ~isfinite(ThetaRecovery.MeanZWrongBand)
        checks(end + 1) = false; %#ok<AGROW>
        messages{end + 1} = 'Wrong-band control could not be computed from finite metrics.'; %#ok<AGROW>
    else
        ThetaRecovery.FalsePositive = ThetaRecovery.MeanZWrongBand > local_max_wrong_band_z(RTConfig);
        checks(end + 1) = ~ThetaRecovery.FalsePositive; %#ok<AGROW>
        if ThetaRecovery.FalsePositive
            messages{end + 1} = 'Wrong-band control failed: false target-theta positive detected.'; %#ok<AGROW>
        else
            messages{end + 1} = 'Wrong-band control passed.'; %#ok<AGROW>
        end
    end
end

%% ===== FINALIZE STATUS =====
% At least one label-driven check must pass for the result to pass.
if isempty(checks)
    ThetaRecovery.Pass = false;
    messages{end + 1} = 'No theta_on or wrong_band blocks were found.'; %#ok<AGROW>
else
    ThetaRecovery.Pass = all(checks);
end
ThetaRecovery.Messages = messages;

end

function ThetaRecovery = local_empty_result(RTConfig, Results, BlockInfo)
% Create the stable output struct with conservative defaults.
ThetaRecovery = struct();
ThetaRecovery.Pass = false;
ThetaRecovery.Messages = {};
ThetaRecovery.TargetBand = local_target_band(RTConfig, Results);
ThetaRecovery.InjectedFrequencies = local_injected_frequencies(BlockInfo);
ThetaRecovery.PSDPeakFrequency = local_psd_peak_frequency(Results);
ThetaRecovery.PeakInsideTargetBand = local_peak_inside_target(Results, ThetaRecovery);
ThetaRecovery.MeanZByBlock = struct('Labels', {{}}, 'Values', []);
ThetaRecovery.MeanPowerByBlock = struct('Labels', {{}}, 'Values', []);
ThetaRecovery.MeanZThetaOn = NaN;
ThetaRecovery.MeanZThetaOff = NaN;
ThetaRecovery.ThetaOnMinusThetaOff = NaN;
ThetaRecovery.MeanZWrongBand = NaN;
ThetaRecovery.FalsePositive = false;
ThetaRecovery.NValidByBlock = struct('Labels', {{}}, 'Values', []);
ThetaRecovery.ConfigHash = local_config_hash(Results);
end

function labels = local_labels(BlockInfo)
% Normalize block labels to a row cell array of chars.
labels = {};
if ~isstruct(BlockInfo) || ~isfield(BlockInfo, 'Labels') || isempty(BlockInfo.Labels)
    return;
end
if iscell(BlockInfo.Labels)
    labels = BlockInfo.Labels(:)';
elseif isstring(BlockInfo.Labels)
    labels = cellstr(BlockInfo.Labels(:))';
elseif ischar(BlockInfo.Labels)
    labels = cellstr(BlockInfo.Labels)';
end
for iLabel = 1:numel(labels)
    labels{iLabel} = char(labels{iLabel});
end
end

function [values, fieldName] = local_preferred_metric(Measures)
% Prefer z-score fields with finite values before falling back to Power.
candidateFields = {'ZSmoothed','ZClipped','ZRaw','Power'};
values = NaN(1, numel(Measures));
fieldName = 'Power';
for iField = 1:numel(candidateFields)
    candidate = local_numeric_vector(Measures, candidateFields{iField});
    if any(isfinite(candidate))
        values = candidate;
        fieldName = candidateFields{iField};
        return;
    end
end
end

function values = local_numeric_vector(S, fieldName)
% Extract a row vector of scalar numeric values.
values = NaN(1, numel(S));
for i = 1:numel(S)
    if isfield(S(i), fieldName)
        value = S(i).(fieldName);
        if isnumeric(value) && ~isempty(value)
            values(i) = double(value(1));
        elseif islogical(value) && ~isempty(value)
            values(i) = double(value(1));
        end
    end
end
end

function sampleIndex = local_measure_samples(Measures)
% Resolve block-alignment samples from common Measure sample fields.
sampleFields = {'CorrectedWindowCenterSample','WindowCenterSample','SampleIndex', ...
    'AcquisitionSampleIndex','FilteredSampleIndex'};
sampleIndex = NaN(1, numel(Measures));
for iField = 1:numel(sampleFields)
    candidate = local_numeric_vector(Measures, sampleFields{iField});
    missing = ~isfinite(sampleIndex) & isfinite(candidate);
    sampleIndex(missing) = candidate(missing);
    if all(isfinite(sampleIndex))
        return;
    end
end
end

function isValid = local_valid_flags(Measures)
% Missing IsValid is treated as valid for small synthetic analysis structs.
isValid = true(1, numel(Measures));
for i = 1:numel(Measures)
    if isfield(Measures(i), 'IsValid') && ~isempty(Measures(i).IsValid)
        isValid(i) = logical(Measures(i).IsValid(1));
    end
end
end

function mask = local_off_block_mask(labels)
% Compare theta_on against theta_off, off, and baseline blocks.
mask = false(size(labels));
for iLabel = 1:numel(labels)
    label = labels{iLabel};
    mask(iLabel) = strcmp(label, 'theta_off') || strcmp(label, 'off') || ...
        strcmp(label, 'baseline');
end
end

function value = local_mean_finite(values)
% Mean without Statistics Toolbox dependency.
values = values(isfinite(values));
if isempty(values)
    value = NaN;
else
    value = mean(values);
end
end

function targetBand = local_target_band(RTConfig, Results)
% Prefer config target band, with validation Results fallbacks.
targetBand = [NaN NaN];
if isfield(RTConfig, 'TargetBand') && isnumeric(RTConfig.TargetBand) && numel(RTConfig.TargetBand) >= 2
    targetBand = double(RTConfig.TargetBand(1:2));
elseif isstruct(Results) && isfield(Results, 'Band') && isfield(Results.Band, 'TargetBand') && ...
        isnumeric(Results.Band.TargetBand) && numel(Results.Band.TargetBand) >= 2
    targetBand = double(Results.Band.TargetBand(1:2));
elseif isstruct(Results) && isfield(Results, 'Step1') && isfield(Results.Step1, 'BandDetection') && ...
        isfield(Results.Step1.BandDetection, 'TargetBand') && ...
        isnumeric(Results.Step1.BandDetection.TargetBand) && numel(Results.Step1.BandDetection.TargetBand) >= 2
    targetBand = double(Results.Step1.BandDetection.TargetBand(1:2));
end
targetBand = reshape(targetBand, 1, []);
end

function freqs = local_injected_frequencies(BlockInfo)
% Copy injected frequencies when available.
if isstruct(BlockInfo) && isfield(BlockInfo, 'InjectFreqHz')
    freqs = reshape(double(BlockInfo.InjectFreqHz), 1, []);
else
    freqs = [];
end
end

function value = local_psd_peak_frequency(Results)
% Read common peak-frequency fields from validation results.
value = NaN;
if ~isstruct(Results)
    return;
end
if isfield(Results, 'Step1') && isfield(Results.Step1, 'BandDetection') && ...
        isfield(Results.Step1.BandDetection, 'PeakFrequency')
    value = local_numeric_scalar(Results.Step1.BandDetection.PeakFrequency);
elseif isfield(Results, 'Band') && isfield(Results.Band, 'PeakFrequency')
    value = local_numeric_scalar(Results.Band.PeakFrequency);
elseif isfield(Results, 'PeakFrequency')
    value = local_numeric_scalar(Results.PeakFrequency);
end
end

function value = local_peak_inside_target(Results, ThetaRecovery)
% Read or infer whether the PSD peak is inside the target band.
value = false;
if isstruct(Results)
    if isfield(Results, 'Step1') && isfield(Results.Step1, 'BandDetection') && ...
            isfield(Results.Step1.BandDetection, 'PeakInsideTargetBand')
        value = logical(Results.Step1.BandDetection.PeakInsideTargetBand(1));
        return;
    elseif isfield(Results, 'Band') && isfield(Results.Band, 'PeakInsideTargetBand')
        value = logical(Results.Band.PeakInsideTargetBand(1));
        return;
    elseif isfield(Results, 'PeakInsideTargetBand')
        value = logical(Results.PeakInsideTargetBand(1));
        return;
    end
end
peak = ThetaRecovery.PSDPeakFrequency;
band = ThetaRecovery.TargetBand;
if isfinite(peak) && all(isfinite(band))
    value = peak >= band(1) && peak <= band(2);
end
end

function value = local_config_hash(Results)
% Read validation config hash when present.
value = '';
if isstruct(Results) && isfield(Results, 'ConfigHash') && ~isempty(Results.ConfigHash)
    value = char(Results.ConfigHash);
end
end

function value = local_numeric_scalar(valueIn)
% Coerce scalar numeric/logical input.
value = NaN;
if isnumeric(valueIn) && ~isempty(valueIn)
    value = double(valueIn(1));
elseif islogical(valueIn) && ~isempty(valueIn)
    value = double(valueIn(1));
end
end

function value = local_min_theta_delta(RTConfig)
% Read theta recovery threshold.
value = 0.5;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'MinThetaOnMinusOffZ') && ...
        isnumeric(RTConfig.Analysis.MinThetaOnMinusOffZ) && ~isempty(RTConfig.Analysis.MinThetaOnMinusOffZ)
    value = double(RTConfig.Analysis.MinThetaOnMinusOffZ(1));
end
end

function value = local_max_wrong_band_z(RTConfig)
% Read wrong-band false-positive threshold.
value = 1.0;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'MaxWrongBandMeanZ') && ...
        isnumeric(RTConfig.Analysis.MaxWrongBandMeanZ) && ~isempty(RTConfig.Analysis.MaxWrongBandMeanZ)
    value = double(RTConfig.Analysis.MaxWrongBandMeanZ(1));
end
end
