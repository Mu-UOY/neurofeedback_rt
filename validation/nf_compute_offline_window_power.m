function RefLike = nf_compute_offline_window_power(Xf, sampleIndices, RTConfig, label)
% NF_COMPUTE_OFFLINE_WINDOW_POWER Compute windowed power from filtered data.
%
% USAGE:  RefLike = nf_compute_offline_window_power(Xf, sampleIndices, RTConfig, label)
%
% DESCRIPTION:
%     Computes mean-squared sliding-window power from already-filtered full
%     offline data. This function does not depend on the streaming buffer.

%% ===== CHECK INPUTS =====
% Xf is filtered post-spatial data.
if ~isnumeric(Xf) || ndims(Xf) ~= 2
    error('Xf must be a numeric [nSignals x nSamples] matrix.');
end

[nSignals, nSamples] = size(Xf);
if nargin < 2 || isempty(sampleIndices)
    sampleIndices = 1:nSamples;
end
sampleIndices = reshape(sampleIndices, 1, []);

if numel(sampleIndices) ~= nSamples
    error('numel(sampleIndices) must match size(Xf,2).');
end

if nargin < 4 || isempty(label)
    label = '';
end

%% ===== RESOLVE WINDOW SETTINGS =====
% Step 1 defaults to the same window and step as the real-time validation.
[W, S] = local_window_settings(RTConfig);
nWindows = max(0, floor((nSamples - W) ./ S) + 1);

%% ===== PREALLOCATE OUTPUT =====
% All sample fields use acquisition sample indices.
RefLike = struct();
RefLike.Power = NaN(1, nWindows);
RefLike.PowerPerSignal = NaN(nSignals, nWindows);
RefLike.SampleIndex = NaN(1, nWindows);
RefLike.Time = NaN(1, nWindows);
RefLike.WindowStartSample = NaN(1, nWindows);
RefLike.WindowEndSample = NaN(1, nWindows);
RefLike.WindowCenterSample = NaN(1, nWindows);
RefLike.IsValid = false(1, nWindows);

%% ===== COMPUTE WINDOWED POWER =====
% Window starts are local array positions; stored samples are acquisition indices.
windowStarts = 1:S:(nSamples - W + 1);
for iWindow = 1:numel(windowStarts)
    windowStart = windowStarts(iWindow);
    windowEnd = windowStart + W - 1;
    windowCenter = windowStart + floor(W / 2);

    xwin = Xf(:, windowStart:windowEnd);
    RefLike.PowerPerSignal(:, iWindow) = mean(xwin .^ 2, 2);
    RefLike.Power(iWindow) = mean(RefLike.PowerPerSignal(:, iWindow));

    RefLike.WindowStartSample(iWindow) = sampleIndices(windowStart);
    RefLike.WindowEndSample(iWindow) = sampleIndices(windowEnd);
    RefLike.WindowCenterSample(iWindow) = sampleIndices(windowCenter);
    RefLike.SampleIndex(iWindow) = RefLike.WindowCenterSample(iWindow);
    RefLike.Time(iWindow) = RefLike.WindowCenterSample(iWindow) ./ RTConfig.Fs;
    RefLike.IsValid(iWindow) = isfinite(RefLike.Power(iWindow));
end

%% ===== PACKAGE METADATA =====
% Metadata is intentionally small and stable for saved validation outputs.
RefLike.Fs = RTConfig.Fs;
RefLike.TargetBand = RTConfig.TargetBand;
RefLike.WindowLength = W;
RefLike.StepSamples = S;
RefLike.Label = char(label);
RefLike.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
RefLike.Metadata = struct();
RefLike.Metadata.NSignals = nSignals;
RefLike.Metadata.NSamples = nSamples;

end

function [W, S] = local_window_settings(RTConfig)
% Read Step 1 window settings with backward-compatible fallbacks.
W = RTConfig.PowerWindowSamples;
S = RTConfig.ChunkSamples;

if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1')
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
