function isValid = nf_validate_spatial_dimensions(Data, RTConfig)
% NF_VALIDATE_SPATIAL_DIMENSIONS Validate data and spatial projection sizes.
%
% USAGE:  isValid = nf_validate_spatial_dimensions(Data, RTConfig)
%
% DESCRIPTION:
%     Confirms that Data.X has the expected channel count and that the
%     configured spatial projection matrix can multiply the dataset channels.

%% ===== CHECK DATA MATRIX =====
% Spatial projection expects [channels x samples] input data.
if ~isstruct(Data) || ~isfield(Data, 'X') || ~isnumeric(Data.X) || ndims(Data.X) ~= 2
    error('Data.X must be a numeric [nChannels x nSamples] matrix.');
end

%% ===== CHECK CHANNEL COUNT =====
% If RTConfig declares a channel count, it must match the dataset.
nChannels = size(Data.X, 1);
if ~isempty(RTConfig.Spatial.NChannels) && RTConfig.Spatial.NChannels ~= nChannels
    error('Data has %d channels but RTConfig.Spatial.NChannels is %d.', ...
        nChannels, RTConfig.Spatial.NChannels);
end

%% ===== BUILD LOCAL SPATIAL MATRIX =====
% Use the dataset channel count to validate generated spatial modes.
localConfig = RTConfig;
localConfig.Spatial.NChannels = nChannels;
CombinedMatrix = nf_build_combined_matrix(localConfig);

%% ===== CHECK MATRIX WIDTH =====
% Projection columns must align with data rows.
if size(CombinedMatrix, 2) ~= nChannels
    error('Spatial matrix has %d columns but data has %d channels.', ...
        size(CombinedMatrix, 2), nChannels);
end

%% ===== RETURN SUCCESS =====
% Mismatches hard-error before this point.
isValid = true;

end
