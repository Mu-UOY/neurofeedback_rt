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

%% ===== PREALLOCATE REFERENCE =====
% One reference point is produced for each complete sliding window.
W = RTConfig.PowerWindowSamples;
discard = Filter.DiscardInitialSamples;
nSamples = size(Xf, 2);
nWindows = max(0, nSamples - W + 1);

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
    windowStart = iWindow;
    windowEnd = iWindow + W - 1;
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
% SampleIndex mirrors the uncorrected window center for direct comparison.
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

end
