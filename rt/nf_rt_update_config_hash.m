function RT = nf_rt_update_config_hash(RT, RTConfig)
% NF_RT_UPDATE_CONFIG_HASH Compute the first-version processing fingerprint.
%
% USAGE:  RT = nf_rt_update_config_hash(RT, RTConfig)
%
% DESCRIPTION:
%     Builds deterministic debugging fingerprints for spatial and filter
%     state, serializes the processing inputs that affect outputs, and stores
%     the resulting config hash on RT.

%% ===== HASH SPATIAL STATE =====
% Spatial hash fingerprints the active projection matrix.
RT.Hash.SpatialHash = local_numeric_hash(RT.Spatial.CombinedMatrix);

%% ===== HASH FILTER STATE =====
% Filter hash fingerprints coefficients and scalar gain when applicable.
switch RT.Filter.Type
    case 'none'
        RT.Hash.FilterHash = 'none';
    case 'iir_sos'
        RT.Hash.FilterHash = local_numeric_hash([RT.Filter.SOS(:); RT.Filter.G]);
    case 'brainstorm_fir'
        RT.Hash.FilterHash = local_numeric_hash([RT.Filter.b(:); RT.Filter.a(:)]);
    otherwise
        error('Unknown filter type: %s', RT.Filter.Type);
end

%% ===== COLLECT HASH INPUTS =====
% Include settings that materially affect streaming outputs.
Inputs = struct();
Inputs.Fs = RTConfig.Fs;
Inputs.ChunkSamples = RTConfig.ChunkSamples;
Inputs.PowerWindowSamples = RTConfig.PowerWindowSamples;
Inputs.BufferSamples = RTConfig.BufferSamples;
Inputs.TargetBand = RTConfig.TargetBand;
Inputs.FilterType = RTConfig.Filter.Type;
Inputs.FilterOrder = local_get_nested(RTConfig, {'Filter','Order'}, []);
Inputs.FilterHash = RT.Hash.FilterHash;
Inputs.FilterDiscardInitialSamples = RT.Filter.DiscardInitialSamples;
Inputs.FilterEmpiricalDelaySamples = local_getfield_default(RT.Filter, 'EmpiricalDelaySamples', NaN);
Inputs.FilterAnalyticGroupDelaySamples = local_getfield_default(RT.Filter, 'AnalyticGroupDelaySamples', NaN);
Inputs.FilterDelayCorrectionUsed = RT.Filter.DelayCorrectionUsed;
Inputs.SpatialMode = RTConfig.Spatial.Mode;
Inputs.SpatialHash = RT.Hash.SpatialHash;
Inputs.SpatialNChannels = RT.Spatial.NChannels;
Inputs.ExpectedChannelNames = local_get_nested(RTConfig, {'Spatial','ExpectedChannelNames'}, {});
Inputs.ZScoreClipRange = RTConfig.ZScore.ClipRange;
Inputs.ZScoreSmoothAlpha = RTConfig.ZScore.SmoothAlpha;
Inputs.SourceMode = RTConfig.Source.Mode;
Inputs.BrainstormVersion = local_get_nested(RTConfig, {'Brainstorm','Version'}, '');
Inputs.BrainstormFilterSpecPath = local_get_nested(RTConfig, {'Brainstorm','FilterSpecPath'}, '');
Inputs.ValidationAlignmentSampleField = local_get_nested(RTConfig, {'Validation','AlignmentSampleField'}, '');
Inputs.SyncSampleIndexTolerance = local_get_nested(RTConfig, {'Sync','SampleIndexTolerance'}, 0);
Inputs.SimulationEnableDroppedChunks = local_get_nested(RTConfig, {'Simulation','EnableDroppedChunks'}, false);
Inputs.SimulationDropProbability = local_get_nested(RTConfig, {'Simulation','DropProbability'}, 0);
Inputs.SimulationDropChunkIndices = local_get_nested(RTConfig, {'Simulation','DropChunkIndices'}, []);
Inputs.SimulationRandomSeed = local_get_nested(RTConfig, {'Simulation','RandomSeed'}, []);

%% ===== COMPUTE CONFIG HASH =====
% Sorted serialization keeps the fingerprint deterministic across runs.
hashString = local_serialize_struct_sorted(Inputs);
RT.ConfigHash = local_string_hash(hashString);
RT.ConfigHashInputs = Inputs;

end

function value = local_get_nested(S, path, defaultValue)
% Read a nested config value without requiring newer fields to exist.
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

function value = local_getfield_default(S, fieldName, defaultValue)
% Read a struct field with a safe fallback.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function hash = local_numeric_hash(x)
% Hash numeric arrays using stable summary statistics and metadata.
if isempty(x)
    hash = 'empty';
    return;
end

xClass = class(x);
xSize = size(x);
x = double(x(:));
finiteX = x(isfinite(x));
if isempty(finiteX)
    stats = [NaN NaN NaN NaN NaN NaN NaN];
else
    stats = [sum(finiteX), mean(finiteX), std(finiteX), ...
        finiteX(1), finiteX(end), min(finiteX), max(finiteX)];
end

payload = [xClass, '|', mat2str(xSize), '|', sprintf('%.17g,', stats)];
hash = local_string_hash(payload);
end

function out = local_serialize_struct_sorted(S)
% Serialize struct fields in sorted order for deterministic hashing.
names = sort(fieldnames(S));
parts = cell(1, numel(names));
for i = 1:numel(names)
    parts{i} = [names{i}, '=', local_value_to_string(S.(names{i}))];
end
out = strjoin(parts, ';');
end

function out = local_value_to_string(value)
% Convert supported MATLAB values into deterministic text.
if isstruct(value)
    out = ['struct(', local_serialize_struct_sorted(value), ')'];
elseif isnumeric(value)
    out = ['numeric[', mat2str(size(value)), '](', sprintf('%.17g,', value(:)), ')'];
elseif islogical(value)
    out = ['logical[', mat2str(size(value)), '](', sprintf('%d,', value(:)), ')'];
elseif ischar(value)
    out = ['char(', value, ')'];
elseif isstring(value)
    out = ['string(', char(value), ')'];
elseif iscell(value)
    cellParts = cell(1, numel(value));
    for i = 1:numel(value)
        cellParts{i} = local_value_to_string(value{i});
    end
    out = ['cell(', strjoin(cellParts, ','), ')'];
else
    out = ['unsupported(', class(value), ')'];
end
end

function hash = local_string_hash(str)
% FNV-1a-style 32-bit hash for compact debugging fingerprints.
bytes = uint16(str(:));
h = uint32(2166136261);
for i = 1:numel(bytes)
    h = bitxor(h, uint32(bytes(i)));
    h = uint32(mod(double(h) * 16777619, 4294967296));
end
hash = upper(dec2hex(double(h), 8));
end
