function hasGap = nf_buffer_window_has_gap(window, RTConfig)
% NF_BUFFER_WINDOW_HAS_GAP Detect discontinuities inside a buffer window.
%
% USAGE:  hasGap = nf_buffer_window_has_gap(window)
%         hasGap = nf_buffer_window_has_gap(window, RTConfig)
%
% DESCRIPTION:
%     Checks sample-index continuity, explicit gap flags, and dropped-sample
%     flags before a window is accepted for power estimation.

%% ===== INITIALIZE OUTPUT =====
% Windows are considered continuous unless a discontinuity is detected.
hasGap = false;

%% ===== READ SYNC TOLERANCE =====
% Optional tolerance allows small index jitter without invalidating a window.
tolerance = 0;
if nargin >= 2 && ~isempty(RTConfig) && isfield(RTConfig, 'Sync') && ...
        isfield(RTConfig.Sync, 'SampleIndexTolerance') && ...
        ~isempty(RTConfig.Sync.SampleIndexTolerance) && ...
        isfinite(RTConfig.Sync.SampleIndexTolerance)
    tolerance = RTConfig.Sync.SampleIndexTolerance;
end

%% ===== HANDLE EMPTY WINDOW =====
% Empty or incomplete metadata cannot prove a gap.
if isempty(window) || ~isfield(window, 'SampleIndex') || isempty(window.SampleIndex)
    return;
end

%% ===== CHECK SAMPLE INDICES =====
% Nonfinite sample indices indicate unusable timing metadata.
sampleIndex = window.SampleIndex;
if any(~isfinite(sampleIndex))
    hasGap = true;
    return;
end

% Consecutive samples should advance by one, within configured tolerance.
sampleJumps = diff(sampleIndex) - 1;
if numel(sampleIndex) > 1 && any(abs(sampleJumps) > tolerance)
    hasGap = true;
    return;
end

%% ===== CHECK GAP FLAGS =====
% Explicit gap flags preserve discontinuities detected before buffering.
if isfield(window, 'GapBeforeSample') && any(window.GapBeforeSample)
    gapFlags = logical(window.GapBeforeSample);
    if gapFlags(1)
        hasGap = true;
        return;
    end
    if numel(sampleIndex) > 1 && any(gapFlags(2:end) & (abs(sampleJumps) > tolerance))
        hasGap = true;
        return;
    end
end

%% ===== CHECK DROPPED FLAGS =====
% Dropped samples anywhere in the returned window invalidate the window.
if isfield(window, 'ContainsDropped') && window.ContainsDropped
    hasGap = true;
end

end
