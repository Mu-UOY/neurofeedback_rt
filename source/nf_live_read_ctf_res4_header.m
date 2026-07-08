function CTFInfo = nf_live_read_ctf_res4_header(Header, RTConfig)
% NF_LIVE_READ_CTF_RES4_HEADER Parse optional CTF res4 metadata.
%
% USAGE:  CTFInfo = nf_live_read_ctf_res4_header(Header, RTConfig)
%
% DESCRIPTION:
%     Extracts CTF metadata defensively from Header.RawHeader.ctf_res4. Missing
%     optional fields are recorded as messages and never faked.

%% ===== INITIALIZE OUTPUT =====
CTFInfo = struct();
CTFInfo.HasCTFRes4 = false;
CTFInfo.ChannelGains = [];
CTFInfo.iMeg = [];
CTFInfo.iMegRef = [];
CTFInfo.iBufMeg = [];
CTFInfo.iBufMegRef = [];
CTFInfo.MegRefCoef = [];
CTFInfo.ChannelMat = [];
CTFInfo.Header = Header;
CTFInfo.Messages = {};
CTFInfo.RequiresMarcConfirmation = local_get_logical(RTConfig, ...
    {'Source','CTF','RequireMarcConfirmation'}, true);
CTFInfo.MarcConfirmed = local_get_logical(RTConfig, ...
    {'Source','CTF','MarcConfirmed'}, false);

%% ===== CHECK RES4 PRESENCE =====
% Required CTF metadata is controlled by config/finalization, not guessed.
hasRaw = isfield(Header, 'RawHeader') && isstruct(Header.RawHeader);
hasRes4 = hasRaw && isfield(Header.RawHeader, 'ctf_res4') && ...
    ~isempty(Header.RawHeader.ctf_res4);
if ~hasRes4
    if local_get_logical(RTConfig, {'Source','FieldTrip','RequireCTFRes4'}, false)
        error('Required CTF ctf_res4 metadata is missing from the live header.');
    end
    CTFInfo.Messages{end+1} = 'CTF ctf_res4 metadata is not present in the live header.';
    return;
end

ctf = Header.RawHeader.ctf_res4;
CTFInfo.HasCTFRes4 = true;

%% ===== EXTRACT KNOWN OPTIONAL FIELDS =====
% Field names can differ across CTF/FieldTrip adapters.
CTFInfo.ChannelGains = local_first_field(ctf, ...
    {'ChannelGains','channel_gains','ChannelGain','gain','Gains'});
CTFInfo.iMeg = local_first_field(ctf, {'iMeg','imeg','MegChannels','meg_channels'});
CTFInfo.iMegRef = local_first_field(ctf, {'iMegRef','imegref','MegRefChannels','meg_ref_channels'});
CTFInfo.iBufMeg = local_first_field(ctf, {'iBufMeg','ibufmeg'});
CTFInfo.iBufMegRef = local_first_field(ctf, {'iBufMegRef','ibufmegref'});
CTFInfo.MegRefCoef = local_first_field(ctf, ...
    {'MegRefCoef','meg_ref_coef','MegRefCoefficients','megrefcoef'});
CTFInfo.ChannelMat = local_first_field(ctf, {'ChannelMat','channelmat'});

%% ===== RECORD MISSING ENABLED METADATA =====
% Correction application decides whether missing metadata is fatal.
if local_get_logical(RTConfig, {'Source','CTF','ApplyChannelGains'}, false) && ...
        isempty(CTFInfo.ChannelGains)
    CTFInfo.Messages{end+1} = 'ChannelGains metadata is missing while ApplyChannelGains is enabled.';
end
if local_get_logical(RTConfig, {'Source','CTF','ApplyMegRefCorrection'}, false) && ...
        (isempty(CTFInfo.MegRefCoef) || isempty(CTFInfo.iMeg) || isempty(CTFInfo.iMegRef))
    CTFInfo.Messages{end+1} = 'MEG reference correction metadata is incomplete while ApplyMegRefCorrection is enabled.';
end

end

function value = local_first_field(S, names)
% Return the first available field from a candidate list.
value = [];
if ~isstruct(S)
    return;
end
for iName = 1:numel(names)
    fieldName = names{iName};
    if isfield(S, fieldName) && ~isempty(S.(fieldName))
        value = S.(fieldName);
        return;
    end
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
