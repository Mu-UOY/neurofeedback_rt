function RT = nf_rt_check_schema(RT)
% NF_RT_CHECK_SCHEMA Validate RT state against the canonical schema.
%
% USAGE:  RT = nf_rt_check_schema(RT)
%
% DESCRIPTION:
%     Confirms that the mutable RT state contains the canonical top-level
%     fields and critical nested fields required by the streaming pipeline.

%% ===== CHECK TOP-LEVEL FIELDS =====
% The empty RT schema defines the required field set.
expected = nf_rt_init_schema();
requiredFields = fieldnames(expected);

for i = 1:numel(requiredFields)
    if ~isfield(RT, requiredFields{i})
        error('RT missing required field: %s', requiredFields{i});
    end
end

%% ===== CHECK REQUIRED SUBFIELDS =====
% These nested values are read during chunk validation and z-score updates.
require_subfield(RT.SampleCounter, 'LastSampleIndex', 'RT.SampleCounter');
require_subfield(RT.SampleCounter, 'LastChunkNSamples', 'RT.SampleCounter');
require_subfield(RT.Timing, 'ChunkProcessingTimes', 'RT.Timing');
require_subfield(RT.ZSmoothState, 'Initialized', 'RT.ZSmoothState');
require_subfield(RT.ZSmoothState, 'Alpha', 'RT.ZSmoothState');

%% ===== CHECK FIELD TYPES =====
% The schema check catches accidental state corruption during development.
if ~islogical(RT.ZSmoothState.Initialized) || ~isscalar(RT.ZSmoothState.Initialized)
    error('RT.ZSmoothState.Initialized must be a scalar logical.');
end
if ~isnumeric(RT.Timing.ChunkProcessingTimes)
    error('RT.Timing.ChunkProcessingTimes must be numeric.');
end

end

function require_subfield(S, fieldName, parentName)
% Raise a clear error for missing nested RT fields.
if ~isfield(S, fieldName)
    error('%s missing required field: %s', parentName, fieldName);
end
end
