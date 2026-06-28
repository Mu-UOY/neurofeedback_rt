function isValid = nf_validate_channel_mapping(ChannelNames, RTConfig)
% NF_VALIDATE_CHANNEL_MAPPING Validate expected channel labels and order.
%
% USAGE:  isValid = nf_validate_channel_mapping(ChannelNames, RTConfig)
%
% DESCRIPTION:
%     Normalizes channel labels and, when ExpectedChannelNames is configured,
%     verifies that the dataset labels exactly match the expected count and
%     ordering.

%% ===== INITIALIZE OUTPUT =====
% This function hard-errors on mismatch and returns true otherwise.
isValid = true;

%% ===== NORMALIZE INPUT LABELS =====
% Missing channel labels are allowed when no expected labels are configured.
if nargin < 1 || isempty(ChannelNames)
    ChannelNames = {};
end
ChannelNames = local_cellstr(ChannelNames);

%% ===== SKIP WHEN NO EXPECTATION EXISTS =====
% ExpectedChannelNames is optional.
if ~isfield(RTConfig.Spatial, 'ExpectedChannelNames') || isempty(RTConfig.Spatial.ExpectedChannelNames)
    return;
end

%% ===== CHECK EXPECTED LABELS =====
% Both count and order must match because spatial projections are positional.
expected = local_cellstr(RTConfig.Spatial.ExpectedChannelNames);

if numel(ChannelNames) ~= numel(expected)
    error('Channel count mismatch: expected %d, received %d.', numel(expected), numel(ChannelNames));
end

% Compare labels one by one for clear mismatch errors.
for i = 1:numel(expected)
    if ~strcmp(ChannelNames{i}, expected{i})
        error('Channel mismatch at position %d: expected "%s", received "%s".', ...
            i, expected{i}, ChannelNames{i});
    end
end

end

function out = local_cellstr(in)
% Normalize MATLAB char, string, or cell channel labels to a row cell array.
if isstring(in)
    out = cellstr(in(:));
elseif ischar(in)
    out = cellstr(in);
elseif iscell(in)
    out = in(:);
else
    error('Channel names must be a cell array, string array, or char array.');
end
out = reshape(out, 1, []);
end
