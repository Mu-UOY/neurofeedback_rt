function Baseline = nf_load_baseline(RTConfig)
% NF_LOAD_BASELINE Load and validate a finalized baseline.
%
% USAGE:  Baseline = nf_load_baseline(RTConfig)
%
% DESCRIPTION:
%     Loads RTConfig.Baseline.Path or the most recent baseline MAT file,
%     rejects partial/unfinalized baselines, and optionally enforces config
%     hash compatibility.

%% ===== RESOLVE BASELINE FILE =====
% Explicit Baseline.Path wins; otherwise use newest baseline_*.mat.
baselinePath = '';
if isfield(RTConfig, 'Baseline') && isfield(RTConfig.Baseline, 'Path') && ...
        ~isempty(RTConfig.Baseline.Path)
    baselinePath = char(RTConfig.Baseline.Path);
else
    baselinePath = local_latest_baseline(RTConfig.Paths.BaselinesDir);
end

if isempty(baselinePath) || exist(baselinePath, 'file') == 0
    error('Baseline file does not exist: %s', baselinePath);
end

%% ===== LOAD AND CHECK BASELINE =====
% Require the canonical saved variable.
loaded = load(baselinePath);
if ~isfield(loaded, 'Baseline')
    error('Baseline MAT file must contain variable Baseline.');
end
Baseline = loaded.Baseline;

if ~isstruct(Baseline) || ~isfield(Baseline, 'Type') || ~strcmp(Baseline.Type, 'baseline')
    error('Loaded baseline has invalid Type.');
end
if isfield(Baseline, 'Partial') && Baseline.Partial
    error('Loaded baseline is partial.');
end
if ~isfield(Baseline, 'Finalized') || ~Baseline.Finalized
    error('Loaded baseline is not finalized.');
end

%% ===== CHECK BASELINE QUALITY =====
% Older finalized baselines may predate count/audit fields; infer counts first.
RTConfig = local_fill_load_baseline_defaults(RTConfig);
Baseline = local_fill_missing_counts(Baseline);
Quality = nf_baseline_check_quality(Baseline, RTConfig);
Baseline.Quality = Quality;

if ~Quality.Pass
    error('Loaded baseline quality failed: %s', Quality.Message);
end

%% ===== CHECK CONFIG HASH =====
% A hash mismatch is fatal when requested and the current hash can be computed.
requireHash = logical(RTConfig.Baseline.RequireConfigHashMatch);

if isempty(local_get_nested(RTConfig, {'Spatial','NChannels'}, []))
    warning(['Skipping baseline config-hash comparison because ', ...
        'RTConfig.Spatial.NChannels is unset and data-dependent.']);
    return;
end

currentHash = local_current_hash_for_baseline_compare(RTConfig, Baseline);
baselineHash = '';
if isfield(Baseline, 'ConfigHash')
    baselineHash = Baseline.ConfigHash;
end

if ~isempty(currentHash) && ~isempty(baselineHash) && ~strcmp(currentHash, baselineHash)
    if requireHash
        error('Baseline config hash mismatch. Current=%s Baseline=%s', currentHash, baselineHash);
    else
        warning('Baseline config hash mismatch ignored because RequireConfigHashMatch=false.');
    end
end

end

function baselinePath = local_latest_baseline(baselineDir)
% Return newest baseline_*.mat file in a directory.
baselinePath = '';
if isempty(baselineDir) || exist(baselineDir, 'dir') == 0
    return;
end
files = dir(fullfile(baselineDir, 'baseline_*.mat'));
if isempty(files)
    return;
end
[~, idx] = max([files.datenum]);
baselinePath = fullfile(files(idx).folder, files(idx).name);
end

function currentHash = local_current_hash_for_baseline_compare(RTConfig, Baseline)
% Compare processing identity while allowing resting/trial source-mode phases.
HashConfig = RTConfig;
if isfield(Baseline, 'ConfigHashInputs') && isfield(Baseline.ConfigHashInputs, 'SourceMode') && ...
        ~isempty(Baseline.ConfigHashInputs.SourceMode)
    HashConfig.Source.Mode = Baseline.ConfigHashInputs.SourceMode;
end
RT = nf_rt_prepare(HashConfig);
currentHash = RT.ConfigHash;
end

function RTConfig = local_fill_load_baseline_defaults(RTConfig)
% Fill only defaults required by baseline loading and quality checks.
if ~isfield(RTConfig, 'Baseline') || isempty(RTConfig.Baseline)
    RTConfig.Baseline = struct();
end
if ~isfield(RTConfig.Baseline, 'MinValidWindows') || isempty(RTConfig.Baseline.MinValidWindows)
    RTConfig.Baseline.MinValidWindows = 10;
end
if ~isfield(RTConfig.Baseline, 'RequireConfigHashMatch') || isempty(RTConfig.Baseline.RequireConfigHashMatch)
    RTConfig.Baseline.RequireConfigHashMatch = true;
end
if ~isfield(RTConfig.Baseline, 'Path') || isempty(RTConfig.Baseline.Path)
    RTConfig.Baseline.Path = '';
end
end

function Baseline = local_fill_missing_counts(Baseline)
% Infer newer count fields from saved values when loading older baselines.
if ~isfield(Baseline, 'UsableWindowCount') || isempty(Baseline.UsableWindowCount)
    if isfield(Baseline, 'TrimmedValues') && ~isempty(Baseline.TrimmedValues)
        Baseline.UsableWindowCount = numel(Baseline.TrimmedValues);
    else
        Baseline.UsableWindowCount = numel(local_baseline_values(Baseline));
    end
end
if ~isfield(Baseline, 'ValidWindowCount') || isempty(Baseline.ValidWindowCount)
    Baseline.ValidWindowCount = numel(local_baseline_values(Baseline));
end
end

function values = local_baseline_values(Baseline)
% Return all valid baseline values when present.
if isfield(Baseline, 'Values')
    values = Baseline.Values;
else
    values = [];
end
end

function value = local_get_nested(S, path, defaultValue)
% Read a nested field with a fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
value = current;
end
