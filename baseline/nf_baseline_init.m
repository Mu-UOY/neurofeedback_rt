function BaselineAcc = nf_baseline_init(RTConfig, RT)
% NF_BASELINE_INIT Initialize a resting baseline accumulator.
%
% USAGE:  BaselineAcc = nf_baseline_init(RTConfig)
%         BaselineAcc = nf_baseline_init(RTConfig, RT)
%
% DESCRIPTION:
%     Creates the mutable accumulator used during resting baseline collection.
%     This can be used for simulated/offline resting or live resting acquisition.

%% ===== PARSE INPUTS =====
% RT is optional; when provided, copy hash provenance into the accumulator.
if nargin < 2
    RT = [];
end

%% ===== INITIALIZE ACCUMULATOR =====
% Partial=true distinguishes this from a saved finalized baseline.
BaselineAcc = struct();
BaselineAcc.Type = 'baseline_accumulator';
BaselineAcc.Partial = true;
BaselineAcc.Finalized = false;
BaselineAcc.Values = [];
BaselineAcc.TrimmedValues = [];
BaselineAcc.RawValues = [];
BaselineAcc.ValidWindowCount = 0;
BaselineAcc.InvalidWindowCount = 0;
BaselineAcc.GapWindowCount = 0;
BaselineAcc.ArtifactWindowCount = 0;
BaselineAcc.InvalidReasonCounts = struct();
BaselineAcc.ConfigHash = '';
BaselineAcc.ConfigHashInputs = struct();
BaselineAcc.ConfigHashCreatedAt = '';
BaselineAcc.Metadata = struct();

%% ===== COPY CONFIG HASH =====
% The baseline is tied to the processing identity that produced its powers.
if isstruct(RT) && isfield(RT, 'ConfigHash')
    BaselineAcc.ConfigHash = RT.ConfigHash;
end
if isstruct(RT) && isfield(RT, 'ConfigHashInputs')
    BaselineAcc.ConfigHashInputs = RT.ConfigHashInputs;
end
if isstruct(RT) && isfield(RT, 'ConfigHash')
    BaselineAcc.ConfigHashCreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

%% ===== RECORD METADATA =====
% Store protocol context needed for later audit and compatibility checks.
BaselineAcc.Metadata.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
BaselineAcc.Metadata.TargetBand = RTConfig.TargetBand;
BaselineAcc.Metadata.Fs = RTConfig.Fs;
BaselineAcc.Metadata.ChunkSamples = RTConfig.ChunkSamples;
BaselineAcc.Metadata.PowerWindowSamples = RTConfig.PowerWindowSamples;
BaselineAcc.Metadata.SourceMode = RTConfig.Source.Mode;

end
