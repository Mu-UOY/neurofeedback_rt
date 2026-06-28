function CombinedMatrix = nf_build_combined_matrix(RTConfig)
% NF_BUILD_COMBINED_MATRIX Build the channel-to-feedback spatial projection.
%
% USAGE:  CombinedMatrix = nf_build_combined_matrix(RTConfig)
%
% DESCRIPTION:
%     Creates the spatial projection matrix for identity, single-channel,
%     channel-average, or user-supplied combined-matrix modes.

%% ===== CHECK SPATIAL CONFIG =====
% Spatial.Mode selects the projection branch below.
if ~isfield(RTConfig, 'Spatial') || ~isfield(RTConfig.Spatial, 'Mode')
    error('RTConfig.Spatial.Mode is required.');
end

%% ===== BUILD PROJECTION MATRIX =====
% nChannels is required for generated projection modes.
nChannels = RTConfig.Spatial.NChannels;
switch RTConfig.Spatial.Mode
    case 'identity'
        % Preserve all channels as independent signals.
        assert_nchannels(nChannels);
        CombinedMatrix = eye(nChannels);

    case 'single_channel'
        % Select exactly one configured channel.
        assert_nchannels(nChannels);
        idx = RTConfig.Spatial.TargetChannelIndex;
        if ~isscalar(idx) || idx < 1 || idx > nChannels || idx ~= round(idx)
            error('RTConfig.Spatial.TargetChannelIndex must be a valid channel index.');
        end
        CombinedMatrix = zeros(1, nChannels);
        CombinedMatrix(idx) = 1;

    case 'channel_average'
        % Average all channels into one feedback signal.
        assert_nchannels(nChannels);
        CombinedMatrix = ones(1, nChannels) ./ nChannels;

    case 'combined_matrix'
        % Use an explicit user-provided projection matrix.
        if isfield(RTConfig.Spatial, 'CombinedMatrix') && ~isempty(RTConfig.Spatial.CombinedMatrix)
            CombinedMatrix = RTConfig.Spatial.CombinedMatrix;
        elseif isfield(RTConfig.Spatial, 'Matrix') && ~isempty(RTConfig.Spatial.Matrix)
            CombinedMatrix = RTConfig.Spatial.Matrix;
        else
            error('RTConfig.Spatial.CombinedMatrix is required for combined_matrix mode.');
        end
        if ~isnumeric(CombinedMatrix) || ndims(CombinedMatrix) ~= 2
            error('CombinedMatrix must be a numeric 2-D matrix.');
        end
        if ~isempty(nChannels) && size(CombinedMatrix, 2) ~= nChannels
            error('CombinedMatrix has %d columns but RTConfig.Spatial.NChannels is %d.', ...
                size(CombinedMatrix, 2), nChannels);
        end

    otherwise
        error('Unknown spatial mode: %s', RTConfig.Spatial.Mode);
end

end

function assert_nchannels(nChannels)
% Generated spatial modes need a known positive integer channel count.
if isempty(nChannels) || ~isscalar(nChannels) || nChannels <= 0 || nChannels ~= round(nChannels)
    error('RTConfig.Spatial.NChannels must be a positive integer for this spatial mode.');
end
end
