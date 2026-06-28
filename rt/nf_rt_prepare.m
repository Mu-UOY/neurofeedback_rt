function RT = nf_rt_prepare(RTConfig, Baseline)
% NF_RT_PREPARE Initialize real-time processing state.
%
% USAGE:  RT = nf_rt_prepare(RTConfig)
%         RT = nf_rt_prepare(RTConfig, Baseline)
%
% DESCRIPTION:
%     Validates configuration, initializes spatial projection, filter,
%     circular buffer, z-score state, optional baseline metadata, and config
%     hash before real-time chunks are processed.

%% ===== PARSE INPUTS =====
% Baseline is optional; when omitted, z-score computation is skipped.
if nargin < 2
    Baseline = [];
end

%% ===== CHECK CONFIGURATION =====
% Ensure paths, modes, dimensions, and dependencies are valid before state init.
RTConfig = nf_check_config(RTConfig);

%% ===== INITIALIZE RT STATE =====
% Start from the canonical schema, then fill prepared runtime fields.
RT = nf_rt_init_schema();
RT.SourceMode = RTConfig.Source.Mode;
RT.PreparedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
RT.HasBaseline = ~isempty(Baseline);

%% ===== INITIALIZE SPATIAL STATE =====
% Projection matrix maps raw channels to feedback signals.
RT.Spatial.Mode = RTConfig.Spatial.Mode;
RT.Spatial.NChannels = RTConfig.Spatial.NChannels;
RT.Spatial.CombinedMatrix = nf_build_combined_matrix(RTConfig);
RT.Spatial.NSignals = size(RT.Spatial.CombinedMatrix, 1);

%% ===== INITIALIZE FILTER AND BUFFER =====
% Filter and buffer operate after spatial projection.
RT.Filter = nf_rt_filter_init(RTConfig, RT.Spatial.NSignals);
RT.Buffer = nf_buffer_init(RT.Spatial.NSignals, RTConfig);

%% ===== INITIALIZE Z-SCORE STATE =====
% Smoothing starts once the first baseline-normalized Measure is valid.
RT.ZSmoothState.Alpha = RTConfig.ZScore.SmoothAlpha;
RT.ZSmoothState.Initialized = false;
RT.ZSmoothState.LastZSmoothed = NaN;
RT.ZSmoothState.LastUpdateSample = NaN;

%% ===== LOAD BASELINE =====
% Baseline field aliases are normalized for z-score computation.
if ~isempty(Baseline)
    RT.Baseline = local_normalize_baseline(Baseline);
    RT.HasBaseline = true;
end

%% ===== COMPUTE CONFIG HASH =====
% Hash inputs capture the processing settings that affect outputs.
RT = nf_rt_update_config_hash(RT, RTConfig);

%% ===== CHECK RT SCHEMA =====
% Optional schema check catches accidental initialization omissions.
if RTConfig.Debug.CheckRTSchema
    RT = nf_rt_check_schema(RT);
end

end

function BaselineOut = local_normalize_baseline(BaselineIn)
% Copy user baseline fields into the canonical RT.Baseline shape.
BaselineOut = nf_rt_init_schema();
BaselineOut = BaselineOut.Baseline;

% Preserve all provided baseline fields.
fields = fieldnames(BaselineIn);
for i = 1:numel(fields)
    BaselineOut.(fields{i}) = BaselineIn.(fields{i});
end

% Accept PowerMean/PowerStd aliases used by earlier baseline outputs.
if isfield(BaselineOut, 'PowerMean') && isfinite(BaselineOut.PowerMean)
    BaselineOut.Mean = BaselineOut.PowerMean;
end
if isfield(BaselineOut, 'PowerStd') && isfinite(BaselineOut.PowerStd)
    BaselineOut.Std = BaselineOut.PowerStd;
end
end
