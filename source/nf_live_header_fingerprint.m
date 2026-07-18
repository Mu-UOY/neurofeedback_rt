function [fingerprint, inputs, version] = nf_live_header_fingerprint(Header)
% NF_LIVE_HEADER_FINGERPRINT Create stable live header structural identity.
%
% USAGE:  [fingerprint, inputs, version] = nf_live_header_fingerprint(Header)
%
% DESCRIPTION:
%     Fingerprints stable structural properties only: sampling rate, channel
%     count, and ordered channel labels. Volatile cursor and endpoint fields
%     such as NSamples, Host, Port, and timestamps are deliberately excluded.

%% ===== NORMALIZE STRUCTURAL INPUTS =====
version = 2;
inputs = struct();
inputs.Fs = local_first_numeric(Header, {'Fs','fsample'}, 'Header.Fs/fsample');
inputs.ChannelNames = local_channel_names(Header);
inputs.NChannels = local_channel_count(Header, inputs.ChannelNames);

if inputs.NChannels ~= numel(inputs.ChannelNames)
    error('Header fingerprint channel count does not match channel label count.');
end

%% ===== HASH STRUCTURAL PAYLOAD =====
payload = sprintf('v=%d|fs=%.17g|nch=%d|labels=%s', version, ...
    inputs.Fs, inputs.NChannels, strjoin(inputs.ChannelNames, char(30)));
fingerprint = local_string_hash(payload);

end

function value = local_first_numeric(S, names, label)
% Return the first finite numeric scalar from a candidate field list.
for iName = 1:numel(names)
    fieldName = names{iName};
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName)) && ...
            isnumeric(S.(fieldName)) && isscalar(S.(fieldName)) && isfinite(S.(fieldName))
        value = double(S.(fieldName));
        return;
    end
end
error('%s must be a finite numeric scalar.', label);
end

function nChannels = local_channel_count(Header, names)
% Resolve a positive integer channel count.
if isstruct(Header) && isfield(Header, 'NChannels') && ~isempty(Header.NChannels)
    raw = Header.NChannels;
elseif isstruct(Header) && isfield(Header, 'nchans') && ~isempty(Header.nchans)
    raw = Header.nchans;
elseif isstruct(Header) && isfield(Header, 'nChans') && ~isempty(Header.nChans)
    raw = Header.nChans;
else
    raw = numel(names);
end
if ~isnumeric(raw) || ~isscalar(raw) || ~isfinite(raw) || raw < 1 || raw ~= round(raw)
    error('Header channel count must be a positive integer scalar.');
end
nChannels = double(raw);
end

function names = local_channel_names(Header)
% Normalize labels to a row cell array while preserving order and text.
if isstruct(Header) && isfield(Header, 'ChannelNames') && ~isempty(Header.ChannelNames)
    names = local_to_cellstr(Header.ChannelNames);
elseif isstruct(Header) && isfield(Header, 'channel_names') && ~isempty(Header.channel_names)
    names = local_to_cellstr(Header.channel_names);
elseif isstruct(Header) && isfield(Header, 'label') && ~isempty(Header.label)
    names = local_to_cellstr(Header.label);
else
    names = {};
end
if isempty(names)
    error('Header channel labels are required for structural fingerprinting.');
end
end

function names = local_to_cellstr(value)
% Convert supported text containers to row cellstr.
if iscell(value)
    names = cell(size(value(:)'));
    for i = 1:numel(value)
        names{i} = char(value{i});
    end
elseif isstring(value)
    names = cellstr(value(:))';
elseif ischar(value)
    if size(value, 1) > 1
        names = cellstr(value)';
    else
        names = {value};
    end
else
    names = {};
end
end

function hash = local_string_hash(str)
% FNV-1a-style 32-bit hash for compact deterministic fingerprints.
bytes = uint16(str(:));
h = uint32(2166136261);
for i = 1:numel(bytes)
    h = bitxor(h, uint32(bytes(i)));
    h = uint32(mod(double(h) * 16777619, 4294967296));
end
hash = upper(dec2hex(double(h), 8));
end
