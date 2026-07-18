function Ref = nf_make_offline_reference(Data, RTConfig)
% NF_MAKE_OFFLINE_REFERENCE Build a causal offline reference power trace.
%
% USAGE:  Ref = nf_make_offline_reference(Data, RTConfig)
%
% DESCRIPTION:
%     Applies the configured spatial projection and causal filter to the full
%     dataset, computes sliding-window power, marks valid windows after
%     filter warmup, and packages the result as the offline reference.

%% ===== CHECK INPUT DATA =====
% The offline reference is computed from the full [channels x samples] matrix.
if ~isstruct(Data) || ~isfield(Data, 'X') || ~isnumeric(Data.X)
    error('Data.X is required.');
end

%% ===== APPLY SPATIAL PROJECTION =====
% Match the same projection used by the streaming path.
localConfig = RTConfig;
localConfig.Spatial.NChannels = size(Data.X, 1);

CombinedMatrix = nf_build_combined_matrix(localConfig);
X = CombinedMatrix * Data.X;

%% ===== INITIALIZE FILTER =====
% Use the real-time filter initializer so coefficients match streaming.
NSignals = size(X, 1);
Filter = nf_rt_filter_init(localConfig, NSignals);
Xf = zeros(size(X));

%% ===== FILTER FULL DATA CAUSALLY =====
% Full-data filtering still uses causal state initialization, not zero-phase filtering.
switch Filter.Type
    case 'none'
        Xf = X;

    case 'iir_sos'
        % Share the offline SOS implementation used by Step 1 filter checks.
        [Xf, IIRInfo] = nf_apply_offline_iir_sos(X, localConfig);
        Filter.DiscardInitialSamples = IIRInfo.DiscardInitialSamples;

    case 'brainstorm_fir'
        % Apply the FIR with zero initial state for a causal reference.
        for iSignal = 1:NSignals
            zi = zeros(max(length(Filter.a), length(Filter.b)) - 1, 1);
            [ys, ~] = filter(Filter.b, Filter.a, X(iSignal, :), zi);
            Xf(iSignal, :) = ys;
        end

    otherwise
        error('Unknown filter type: %s', Filter.Type);
end

%% ===== RESOLVE REFERENCE WINDOWS =====
% One reference point is produced for each configured complete window.
W = RTConfig.PowerWindowSamples;
discard = Filter.DiscardInitialSamples;
nSamples = size(Xf, 2);
[referenceStrideMode, referenceStepSamples] = local_reference_stride_settings(RTConfig);

firstWindowEnd = W;
lastWindowEnd = nSamples;
if lastWindowEnd < firstWindowEnd
    windowEnds = [];
else
    switch referenceStrideMode
        case 'dense'
            windowEnds = firstWindowEnd:lastWindowEnd;

        case 'step'
            windowEnds = firstWindowEnd:referenceStepSamples:lastWindowEnd;

        otherwise
            error('Unknown ReferenceStrideMode: %s', referenceStrideMode);
    end
end
nWindows = numel(windowEnds);

%% ===== PREALLOCATE REFERENCE =====
% Store both center and end samples so alignment and chunk diagnostics are explicit.
Ref = struct();
Ref.Power = NaN(1, nWindows);
Ref.PowerPerSignal = NaN(NSignals, nWindows);
Ref.WindowStartSample = NaN(1, nWindows);
Ref.WindowEndSample = NaN(1, nWindows);
Ref.WindowCenterSample = NaN(1, nWindows);
Ref.IsValid = false(1, nWindows);

%% ===== COMPUTE WINDOWED POWER =====
% Windows starting during filter warmup remain invalid.
for iWindow = 1:nWindows
    windowEnd = windowEnds(iWindow);
    windowStart = windowEnd - W + 1;
    windowCenter = windowStart + floor(W / 2);

    Ref.WindowStartSample(iWindow) = windowStart;
    Ref.WindowEndSample(iWindow) = windowEnd;
    Ref.WindowCenterSample(iWindow) = windowCenter;

    if windowStart <= discard
        continue;
    end

    % Mean squared amplitude is computed per signal and then averaged.
    xwin = Xf(:, windowStart:windowEnd);
    Ref.PowerPerSignal(:, iWindow) = mean(xwin .^ 2, 2);
    Ref.Power(iWindow) = mean(Ref.PowerPerSignal(:, iWindow));
    Ref.IsValid(iWindow) = isfinite(Ref.Power(iWindow));
end

%% ===== PACKAGE REFERENCE METADATA =====
% Ref.SampleIndex is the uncorrected window center sample for backward
% compatibility and direct comparison with Measure.WindowCenterSample.
% WindowEndSample is stored separately for chunk-boundary diagnostics.
Ref.SampleIndex = Ref.WindowCenterSample;
Ref.Time = Ref.WindowCenterSample ./ Data.Fs;
Ref.Fs = Data.Fs;
Ref.TargetBand = RTConfig.TargetBand;
Ref.FilterType = RTConfig.Filter.Type;
Ref.FilterCausality = 'causal';
Ref.WindowLength = W;
Ref.DiscardInitialSamples = discard;

%% ===== COPY DATASET METADATA =====
% Preserve dataset provenance and optional annotations in the reference.
if isfield(Data, 'Metadata') && isfield(Data.Metadata, 'SourceFile')
    Ref.DatasetName = Data.Metadata.SourceFile;
else
    Ref.DatasetName = '';
end
if isfield(Data, 'ChannelNames')
    Ref.ChannelNames = Data.ChannelNames;
else
    Ref.ChannelNames = {};
end
if isfield(Data, 'Events')
    Ref.Events = Data.Events;
else
    Ref.Events = [];
end
Ref.Metadata.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Ref.Metadata.ReferenceStrideMode = referenceStrideMode;
Ref.Metadata.ReferenceStepSamples = referenceStepSamples;
Ref.Metadata.WindowCount = nWindows;
Ref.Metadata.DenseEquivalentAvailable = strcmp(referenceStrideMode, 'dense');
Ref.Metadata.PowerWindowSamples = W;
Ref.Metadata.ChunkSamples = RTConfig.ChunkSamples;

end

function [strideMode, stepSamples] = local_reference_stride_settings(RTConfig)
% Resolve dense versus stepped reference generation.
strideMode = 'dense';
if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'ReferenceStrideMode') && ...
        ~isempty(RTConfig.Validation.Step1.ReferenceStrideMode)
    strideMode = lower(char(RTConfig.Validation.Step1.ReferenceStrideMode));
end

switch strideMode
    case 'dense'
        stepSamples = 1;

    case 'step'
        stepSamples = local_resolve_reference_step_samples(RTConfig);

    otherwise
        error('Unknown ReferenceStrideMode: %s', strideMode);
end
end

function stepSamples = local_resolve_reference_step_samples(RTConfig)
% Read stepped-reference stride with documented fallbacks.
stepSamples = [];
if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1')
    step1 = RTConfig.Validation.Step1;
    if isfield(step1, 'ReferenceStepSamples') && local_is_positive_scalar(step1.ReferenceStepSamples)
        stepSamples = step1.ReferenceStepSamples;
    elseif isfield(step1, 'StepSamples') && local_is_positive_scalar(step1.StepSamples)
        stepSamples = step1.StepSamples;
    end
end
if isempty(stepSamples) && isfield(RTConfig, 'ChunkSamples') && local_is_positive_scalar(RTConfig.ChunkSamples)
    stepSamples = RTConfig.ChunkSamples;
end
if isempty(stepSamples)
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
