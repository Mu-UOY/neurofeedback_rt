function [chunk, RT] = nf_rt_apply_spatial(chunk, RT, RTConfig) %#ok<INUSD>
% NF_RT_APPLY_SPATIAL Apply the configured spatial projection.
%
% USAGE:  [chunk, RT] = nf_rt_apply_spatial(chunk, RT, RTConfig)
%
% DESCRIPTION:
%     Multiplies the incoming chunk data by the prepared spatial projection
%     matrix and updates the chunk signal count after projection.

%% ===== CHECK SPATIAL MATRIX =====
% The prepared RT state owns the projection used during streaming.
M = RT.Spatial.CombinedMatrix;
if isempty(M)
    error('RT.Spatial.CombinedMatrix is empty.');
end

% Matrix columns must align with raw channel rows in the chunk.
if size(M, 2) ~= size(chunk.Data, 1)
    error('Spatial matrix has %d columns but chunk has %d channels.', size(M, 2), size(chunk.Data, 1));
end

%% ===== APPLY SPATIAL PROJECTION =====
% After projection, rows are feedback signals rather than raw channels.
chunk.Data = M * chunk.Data;
chunk.NSignals = size(chunk.Data, 1);

end
