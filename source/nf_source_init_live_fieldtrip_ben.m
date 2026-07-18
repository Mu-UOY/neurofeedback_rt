function Source = nf_source_init_live_fieldtrip_ben(RTConfig)
% NF_SOURCE_INIT_LIVE_FIELDTRIP_BEN Initialize Ben-compatible live source.
%
% USAGE:  Source = nf_source_init_live_fieldtrip_ben(RTConfig)
%
% DESCRIPTION:
%     Connects to the configured FieldTrip realtime buffer, reads the live
%     header, records CTF metadata availability, detects acquisition block
%     size, and initializes a source cursor at the current live sample count.

%% ===== RUN LIVE ACQUISITION CHECKS =====
% Each helper owns one part of the acquisition-only setup.
PathInfo = nf_live_add_fieldtrip_paths(RTConfig);
Header = nf_live_read_header_fieldtrip(RTConfig);
CTFInfo = nf_live_read_ctf_res4_header(Header, RTConfig);
BlockInfo = nf_live_detect_acq_block_size(RTConfig, Header);

%% ===== BUILD SOURCE STRUCT =====
% LastSampleRead starts at the current live buffer end so future reads do
% not replay old buffer history.
Source = struct();
Source.Mode = RTConfig.Source.Mode;
Source.LiveAdapter = RTConfig.Source.LiveAdapter;
Source.PathInfo = PathInfo;
Source.Header = Header;
Source.RawHeader = Header.RawHeader;
Source.HeaderFingerprint = Header.StructuralFingerprint;
Source.HeaderFingerprintInputs = Header.StructuralFingerprintInputs;
Source.HeaderFingerprintVersion = Header.StructuralFingerprintVersion;
% HeaderHash is a legacy field name; it now aliases the stable structural
% fingerprint and excludes volatile NSamples.
Source.HeaderHash = Source.HeaderFingerprint;
Source.Fs = Header.Fs;
Source.NChannels = Header.NChannels;
Source.ChannelNames = Header.ChannelNames;
Source.InitialSample = Header.NSamples;
Source.LastSampleRead = Header.NSamples;
Source.AcquisitionBlockSamples = BlockInfo.AcquisitionBlockSamples;
Source.AcquisitionBlockSeconds = BlockInfo.AcquisitionBlockSeconds;
Source.BlockInfo = BlockInfo;
Source.ChannelGains = CTFInfo.ChannelGains;
Source.iMeg = CTFInfo.iMeg;
Source.iMegRef = CTFInfo.iMegRef;
Source.MegRefCoef = CTFInfo.MegRefCoef;
Source.CTFInfo = CTFInfo;
Source.ChannelNamesAfterCorrection = Header.ChannelNames;
Source.CorrectionState = local_correction_state(RTConfig, CTFInfo);
Source.IsLive = true;
Source.IsMockLive = false;
Source.LastError = '';
Source.TimeoutCount = 0;
Source.ConsecutiveTimeoutCount = 0;
Source.BufferResetCount = 0;
Source.LastBufferHeaderNSamples = Header.NSamples;
Source.LastReadStatus = 'initialized';
Source.Messages = [PathInfo.Messages, CTFInfo.Messages, BlockInfo.Messages];
Source.SettingOrigin = RTConfig.Source.FieldTrip.SettingOrigin;
Source.ResolvedConnection = local_resolved_connection(RTConfig, Header, PathInfo);

%% ===== COPY CONVENIENCE ALIASES =====
% These top-level fields must mirror ResolvedConnection exactly.
Source.Host = Source.ResolvedConnection.Host;
Source.Port = Source.ResolvedConnection.Port;
Source.TimeoutMs = Source.ResolvedConnection.TimeoutMs;

%% ===== PRINT SUMMARY =====
% Keep automated tests quiet unless verbose diagnostics are requested.
if isfield(RTConfig, 'Debug') && isfield(RTConfig.Debug, 'Verbose') && RTConfig.Debug.Verbose
    fprintf('Live FieldTrip source initialized\n');
    fprintf('  Host/port:              %s / %s\n', local_text(Source.Host), local_text(Source.Port));
    fprintf('  Fs:                     %g Hz\n', Source.Fs);
    fprintf('  Channels:               %d\n', Source.NChannels);
    fprintf('  Initial sample:         %d\n', Source.InitialSample);
    fprintf('  Acquisition block:      %s samples\n', local_text(Source.AcquisitionBlockSamples));
    fprintf('  CTF res4:               %d\n', CTFInfo.HasCTFRes4);
    fprintf('  ChannelGains available: %d\n', ~isempty(CTFInfo.ChannelGains));
    fprintf('  MegRefCoef available:   %d\n', ~isempty(CTFInfo.MegRefCoef));
    fprintf('  MarcConfirmed:          %d\n', Source.CorrectionState.MarcConfirmed);
    fprintf('  buffer.m:               %s\n', Source.ResolvedConnection.SelectedBufferFunction);
    fprintf('  TestBufferFcn:          %d\n', Source.ResolvedConnection.UsedTestHook);
end

end

function ResolvedConnection = local_resolved_connection(RTConfig, Header, PathInfo)
% Record the actual runtime connection values used.
ResolvedConnection = struct();
ResolvedConnection.Host = RTConfig.Source.FieldTrip.Host;
ResolvedConnection.Port = RTConfig.Source.FieldTrip.Port;
ResolvedConnection.TimeoutMs = RTConfig.Source.FieldTrip.TimeoutMs;
ResolvedConnection.BufferMPath = RTConfig.Source.FieldTrip.BufferMPath;
ResolvedConnection.FieldTripRoot = RTConfig.Source.FieldTrip.FieldTripRoot;
ResolvedConnection.RequiredBufferRoot = RTConfig.Source.FieldTrip.RequiredBufferRoot;
ResolvedConnection.SelectedBufferFunction = Header.ResolvedConnection.SelectedBufferFunction;
ResolvedConnection.AllBufferCandidates = PathInfo.AllBufferPaths;
ResolvedConnection.UsedTestHook = Header.ResolvedConnection.UsedTestHook;
ResolvedConnection.StreamRole = Header.ResolvedConnection.StreamRole;
ResolvedConnection.FieldTripVersion = local_field(PathInfo, 'FieldTripVersion', '');
ResolvedConnection.FtRealtimeFileProxyExists = local_field(PathInfo, 'FtRealtimeFileProxyExists', false);
ResolvedConnection.FtRealtimeFileProxyPath = local_field(PathInfo, 'FtRealtimeFileProxyPath', '');
ResolvedConnection.BenjaminEvidenceFiles = RTConfig.Source.Benjamin.WiringEvidenceFiles;
end

function CorrectionState = local_correction_state(RTConfig, CTFInfo)
% Describe intended candidate correction state without claiming final parity.
CorrectionState = struct();
CorrectionState.AppliedChannelGains = false;
CorrectionState.AppliedMegRefCorrection = false;
CorrectionState.RemovedBlockMean = RTConfig.Source.CTF.RemoveBlockMean;
CorrectionState.AppliedProjector = false;
CorrectionState.HasCTFRes4 = CTFInfo.HasCTFRes4;
CorrectionState.RequiresMarcConfirmation = RTConfig.Source.CTF.RequireMarcConfirmation;
CorrectionState.MarcConfirmed = RTConfig.Source.CTF.MarcConfirmed;
CorrectionState.CorrectionOrder = RTConfig.Source.CTF.CorrectionOrder;
CorrectionState.Messages = CTFInfo.Messages;
if CorrectionState.RequiresMarcConfirmation && ~CorrectionState.MarcConfirmed
    CorrectionState.Messages{end+1} = ...
        'Candidate CTF correction order requires Marc confirmation before claiming Benjamin equivalence.';
end
end

function textValue = local_text(value)
% Convert simple values to printable text.
if isempty(value)
    textValue = '';
elseif isnumeric(value) && isscalar(value)
    textValue = num2str(value);
elseif ischar(value)
    textValue = value;
elseif isstring(value)
    textValue = char(value);
else
    textValue = '<non-scalar>';
end
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
