function Header = nf_live_read_header_fieldtrip(RTConfig)
% NF_LIVE_READ_HEADER_FIELDTRIP Read and validate a FieldTrip live header.
%
% USAGE:  Header = nf_live_read_header_fieldtrip(RTConfig)
%
% DESCRIPTION:
%     Reads one FieldTrip realtime header through nf_live_buffer_call and
%     extracts the minimal audit fields needed for the live channel check.

%% ===== READ RAW HEADER =====
% All live buffer access goes through the wrapper so tests can use a fake.
hdr = nf_live_buffer_call(RTConfig, 'get_hdr', []);
if isempty(hdr) || ~isstruct(hdr)
    error('FieldTrip get_hdr returned an empty or non-struct header.');
end

%% ===== EXTRACT HEADER FIELDS =====
% FieldTrip/Brainstorm header field names may vary slightly across adapters.
Header = struct();
Header.Fs = local_required_numeric(hdr, 'fsample', 'hdr.fsample');
Header.NSamples = local_required_numeric(hdr, 'nsamples', 'hdr.nsamples');
Header.ChannelNames = local_channel_names(hdr);
Header.NChannels = local_nchannels(hdr, Header.ChannelNames);
Header.RawHeader = hdr;
Header.HasCTFRes4 = isfield(hdr, 'ctf_res4') && ~isempty(hdr.ctf_res4);
Header.SettingOrigin = RTConfig.Source.FieldTrip.SettingOrigin;
Header.ResolvedConnection = local_resolved_connection(RTConfig);

%% ===== VALIDATE CHANNEL LABELS =====
% Missing labels are a formal channel/header check failure when required.
requireLabels = local_get_logical(RTConfig, {'LiveDryRun','RequireChannelLabels'}, true);
if requireLabels && isempty(Header.ChannelNames)
    error('FieldTrip header does not contain channel labels.');
end

%% ===== VALIDATE SAMPLING RATE =====
% Step 3A live checks expect 2400 Hz unless explicitly disabled.
requireFsMatch = local_get_logical(RTConfig, {'LiveDryRun','RequireSamplingRateMatch'}, true);
if requireFsMatch
    expectedFs = local_expected_fs(RTConfig);
    if abs(Header.Fs - expectedFs) > 1e-9
        error('FieldTrip header Fs mismatch: got %g Hz, expected %g Hz.', ...
            Header.Fs, expectedFs);
    end
end

%% ===== VALIDATE REQUIRED CTF HEADER =====
% The parser performs detailed extraction; this function only gates presence.
requireCTFRes4 = local_get_logical(RTConfig, {'Source','FieldTrip','RequireCTFRes4'}, false);
if requireCTFRes4 && ~Header.HasCTFRes4
    error('FieldTrip header does not contain required ctf_res4 metadata.');
end

end

function value = local_required_numeric(S, fieldName, label)
% Extract a finite numeric scalar from a raw header.
if ~isfield(S, fieldName) || isempty(S.(fieldName)) || ...
        ~isnumeric(S.(fieldName)) || ~isscalar(S.(fieldName)) || ~isfinite(S.(fieldName))
    error('%s must be a finite numeric scalar.', label);
end
value = double(S.(fieldName));
end

function names = local_channel_names(hdr)
% Extract channel labels from common FieldTrip/Brainstorm header fields.
names = {};
if isfield(hdr, 'channel_names') && ~isempty(hdr.channel_names)
    names = local_to_cellstr(hdr.channel_names);
elseif isfield(hdr, 'label') && ~isempty(hdr.label)
    names = local_to_cellstr(hdr.label);
end
end

function nChannels = local_nchannels(hdr, names)
% Prefer hdr.nchans, falling back to label count.
if isfield(hdr, 'nchans') && ~isempty(hdr.nchans) && isnumeric(hdr.nchans)
    nChannels = double(hdr.nchans);
else
    nChannels = numel(names);
end
end

function names = local_to_cellstr(value)
% Normalize labels to a row cell array of char.
if iscell(value)
    names = value(:)';
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

function ResolvedConnection = local_resolved_connection(RTConfig)
% Copy the runtime connection subset used by both Header and Source.
usedTestHook = ~isempty(RTConfig.Source.FieldTrip.TestBufferFcn);
if usedTestHook
    selectedBuffer = 'test_hook';
else
    selectedBuffer = which('buffer');
end
ResolvedConnection = struct();
ResolvedConnection.Host = RTConfig.Source.FieldTrip.Host;
ResolvedConnection.Port = RTConfig.Source.FieldTrip.Port;
ResolvedConnection.SelectedBufferFunction = selectedBuffer;
ResolvedConnection.UsedTestHook = usedTestHook;
end

function expectedFs = local_expected_fs(RTConfig)
% Resolve the expected live sampling rate.
if isfield(RTConfig, 'LiveDryRun') && isfield(RTConfig.LiveDryRun, 'ExpectedFs') && ...
        ~isempty(RTConfig.LiveDryRun.ExpectedFs)
    expectedFs = RTConfig.LiveDryRun.ExpectedFs;
else
    expectedFs = RTConfig.Fs;
end
end

function value = local_get_logical(S, path, defaultValue)
% Read optional nested logical field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
if islogical(cursor) && isscalar(cursor)
    value = cursor;
end
end
