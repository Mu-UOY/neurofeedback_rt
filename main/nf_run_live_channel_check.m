function Check = nf_run_live_channel_check(RTConfig)
% NF_RUN_LIVE_CHANNEL_CHECK Run the formal acquisition-only channel check.
%
% USAGE:  Check = nf_run_live_channel_check(RTConfig)
%
% DESCRIPTION:
%     Creates one session folder, attempts live FieldTrip source/header
%     initialization, and saves a PASS/FAIL channel/header report whenever a
%     session folder was successfully created.

%% ===== PREPARE CONFIG AND SESSION =====
% The session is created before risky live checks so failures can be saved.
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_live_config();
end
Modes = nf_modes();
RTConfig.Session.Mode = Modes.Session.LiveChannelCheck;

if ~isfield(RTConfig, 'Paths') || ~isfield(RTConfig.Paths, 'ProjectRoot') || ...
        isempty(RTConfig.Paths.ProjectRoot)
    RTConfig.Paths.ProjectRoot = nf_project_root();
end

Session = nf_make_session_output_dir(RTConfig, 'live_channel_check');
Check = local_empty_check(RTConfig, Session);

%% ===== RUN RISKY LIVE OPERATIONS =====
% Do not let config/path/header/source errors escape before saving a report.
try
    RTConfig = nf_finalize_config(RTConfig);
    Source = nf_source_init(RTConfig.Source.Mode, [], RTConfig);

    Check = local_populate_check(Check, Source, RTConfig, Session);
    [Check.Pass, Check.Messages] = local_pass_criteria(Check, Source, RTConfig);
    if Check.Pass
        Check.Status = 'PASS';
        Check.Recommendation = 'Live channel/header check passed.';
    else
        Check.Status = 'FAIL';
        Check.Recommendation = local_recommendation(Check);
    end
catch ME
    Check.Status = 'FAIL';
    Check.Pass = false;
    Check.Messages{end+1} = sprintf('%s: %s', ME.identifier, ME.message);
    Check.Error.Identifier = ME.identifier;
    Check.Error.Message = ME.message;
    Check.Error.Report = getReport(ME, 'basic', 'hyperlinks', 'off');
    Check.Recommendation = local_recommendation(Check);
end

%% ===== SAVE REPORT =====
% Save failures are rethrown because the diagnostic artifact was not written.
try
    Paths = nf_save_live_channel_check(Check, RTConfig, Session);
    Check.ReportPaths = Paths;
catch SaveME
    error('Failed to save live channel check report: %s', SaveME.message);
end

end

function Check = local_empty_check(RTConfig, Session)
% Build conservative failure defaults that tolerate missing config fields.
FT = local_field(local_field(RTConfig, 'Source', struct()), 'FieldTrip', struct());
LiveDryRun = local_field(RTConfig, 'LiveDryRun', struct());

Check = struct();
Check.Status = 'FAIL';
Check.Pass = false;
Check.Host = local_field(FT, 'Host', '');
Check.Port = local_field(FT, 'Port', []);
Check.SettingOrigin = local_field(FT, 'SettingOrigin', struct());
Check.ResolvedConnection = struct();
Check.PathInfo = struct();
Check.Header = struct();
Check.RawHeaderSummary = struct();
Check.Fs = NaN;
Check.ExpectedFs = local_field(LiveDryRun, 'ExpectedFs', 2400);
Check.FsMatches = false;
Check.NChannels = NaN;
Check.InitialNSamples = NaN;
Check.SecondNSamples = NaN;
Check.SampleCountAdvanced = false;
Check.AcquisitionBlockSamples = NaN;
Check.AcquisitionBlockSeconds = NaN;
Check.HasCTFRes4 = false;
Check.HasChannelGains = false;
Check.HasMegRefCoef = false;
Check.CorrectionState = struct();
Check.ChannelNames = {};
Check.ChannelNamesAfterCorrection = {};
Check.OutputDir = Session.ReportsDir;
Check.ReportPaths = struct();
Check.BenIndexingNote = '';
Check.Recommendation = '';
Check.Messages = {};
Check.Error = struct();
end

function Check = local_populate_check(Check, Source, RTConfig, Session)
% Copy source/header diagnostics into the user-facing check struct.
Check.Host = Source.Host;
Check.Port = Source.Port;
Check.SettingOrigin = Source.SettingOrigin;
Check.ResolvedConnection = Source.ResolvedConnection;
Check.PathInfo = Source.PathInfo;
Check.Header = Source.Header;
Check.RawHeaderSummary = local_raw_header_summary(Source.Header);
Check.Fs = Source.Fs;
Check.ExpectedFs = RTConfig.LiveDryRun.ExpectedFs;
Check.FsMatches = abs(Source.Fs - Check.ExpectedFs) <= 1e-9;
Check.NChannels = Source.NChannels;
Check.InitialNSamples = Source.InitialSample;
Check.SecondNSamples = Source.BlockInfo.SecondNSamples;
Check.SampleCountAdvanced = isfinite(Source.AcquisitionBlockSamples) && Source.AcquisitionBlockSamples > 0;
Check.AcquisitionBlockSamples = Source.AcquisitionBlockSamples;
Check.AcquisitionBlockSeconds = Source.AcquisitionBlockSeconds;
Check.HasCTFRes4 = Source.CTFInfo.HasCTFRes4;
Check.HasChannelGains = ~isempty(Source.ChannelGains);
Check.HasMegRefCoef = ~isempty(Source.MegRefCoef);
Check.CorrectionState = Source.CorrectionState;
Check.ChannelNames = Source.ChannelNames;
Check.ChannelNamesAfterCorrection = Source.ChannelNamesAfterCorrection;
Check.OutputDir = Session.ReportsDir;
Check.BenIndexingNote = ['chunk.SampleIndex/SampleIndices are one-based logical samples; ', ...
    'FieldTripReadRange is zero-based inclusive transport metadata. Confirm ', ...
    'this convention in the MEG room before claiming final neural timing.'];
Check.Messages = Source.Messages;
end

function [pass, messages] = local_pass_criteria(Check, Source, RTConfig)
% Evaluate formal Step 3A channel/header pass criteria.
messages = Check.Messages;
pass = true;

pass = local_require_check(pass, Check.FsMatches, messages, ...
    'Header sampling rate does not match expected live Fs.');
messages = local_append_if(messages, ~Check.FsMatches, ...
    'Header sampling rate does not match expected live Fs.');

hasLabels = ~isempty(Check.ChannelNames);
messages = local_append_if(messages, ~hasLabels, 'Channel labels are missing.');
pass = pass && hasLabels;

hasChannels = isfinite(Check.NChannels) && Check.NChannels > 0;
messages = local_append_if(messages, ~hasChannels, 'NChannels is missing or zero.');
pass = pass && hasChannels;

messages = local_append_if(messages, ~Check.SampleCountAdvanced, ...
    'Sample count did not advance during acquisition block detection.');
pass = pass && Check.SampleCountAdvanced;

requireCTF = RTConfig.Source.FieldTrip.RequireCTFRes4;
messages = local_append_if(messages, requireCTF && ~Check.HasCTFRes4, ...
    'Required CTF res4 metadata is missing.');
pass = pass && ~(requireCTF && ~Check.HasCTFRes4);

toolboxSelected = isfield(Source.PathInfo, 'BufferLooksLikeMatlabToolbox') && ...
    Source.PathInfo.BufferLooksLikeMatlabToolbox;
allowToolbox = RTConfig.Source.FieldTrip.AllowMatlabToolboxBuffer;
messages = local_append_if(messages, toolboxSelected && ~allowToolbox, ...
    'MATLAB toolbox buffer.m was selected without explicit allowance.');
pass = pass && ~(toolboxSelected && ~allowToolbox);

if ~Source.ResolvedConnection.UsedTestHook
    unresolvedHost = strcmp(Check.SettingOrigin.Host, 'unresolved');
    unresolvedPort = strcmp(Check.SettingOrigin.Port, 'unresolved');
    messages = local_append_if(messages, unresolvedHost || unresolvedPort, ...
        'Required live host/port setting origins remain unresolved.');
    pass = pass && ~(unresolvedHost || unresolvedPort);
end
end

function pass = local_require_check(pass, condition, ~, ~)
% Preserve a compact pass update expression.
pass = pass && condition;
end

function messages = local_append_if(messages, condition, message)
% Append failure message when needed.
if condition
    messages{end+1} = message;
end
end

function Recommendation = local_recommendation(Check)
% Provide actionable next steps for common live setup failures.
Recommendation = ['Fill RTConfig.Source.FieldTrip.Host and Port if using the real buffer; ', ...
    'set BufferMPath or FieldTripRoot to the exact FieldTrip realtime buffer path; ', ...
    'confirm the FieldTrip/Brainstorm buffer is running; verify buffer.m shadowing; ', ...
    'use TestBufferFcn only for automated tests.'];
if isfield(Check, 'Messages') && ~isempty(Check.Messages)
    Recommendation = [Recommendation ' First issue: ' Check.Messages{1}];
end
end

function Summary = local_raw_header_summary(Header)
% Keep a small audit subset rather than duplicating huge raw metadata.
Summary = struct();
Summary.Fs = local_field(Header, 'Fs', NaN);
Summary.NSamples = local_field(Header, 'NSamples', NaN);
Summary.NChannels = local_field(Header, 'NChannels', NaN);
Summary.HasCTFRes4 = local_field(Header, 'HasCTFRes4', false);
end

function value = local_field(S, fieldName, defaultValue)
% Read optional struct field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
