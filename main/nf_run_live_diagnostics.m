function Diagnostics = nf_run_live_diagnostics(RTConfig)
% NF_RUN_LIVE_DIAGNOSTICS Run acquisition-only live buffer diagnostics.
%
% USAGE:  Diagnostics = nf_run_live_diagnostics(RTConfig)
%
% DESCRIPTION:
%     Prints and returns live FieldTrip/Brainstorm buffer diagnostics without
%     starting baseline, trial, feedback, or RT processing.

%% ===== PREPARE CONFIG =====
% Diagnostics is acquisition-only.
if nargin < 1 || isempty(RTConfig)
    RTConfig = nf_live_config();
end
Modes = nf_modes();
RTConfig.Session.Mode = Modes.Session.LiveDiagnostics;

Diagnostics = struct();
Diagnostics.Status = 'FAIL';
Diagnostics.Messages = {};

try
    RTConfig = nf_finalize_config(RTConfig);
    Source = nf_source_init(RTConfig.Source.Mode, [], RTConfig);
    DryRun = nf_source_dry_run(Source, RTConfig);

    Diagnostics.Status = 'PASS';
    Diagnostics.RTConfig = RTConfig;
    Diagnostics.Source = Source;
    Diagnostics.DryRun = DryRun;
    Diagnostics.PathInfo = Source.PathInfo;
    Diagnostics.Header = Source.Header;
    Diagnostics.CTFInfo = Source.CTFInfo;
    Diagnostics.CorrectionState = Source.CorrectionState;
    Diagnostics.Messages = Source.Messages;

    local_print_diagnostics(Diagnostics);
catch ME
    Diagnostics.Error.Identifier = ME.identifier;
    Diagnostics.Error.Message = ME.message;
    Diagnostics.Error.Report = getReport(ME, 'basic', 'hyperlinks', 'off');
    Diagnostics.Messages{end+1} = ME.message;
    fprintf('Live diagnostics failed: %s\n', ME.message);
end

end

function local_print_diagnostics(Diagnostics)
% Print concise MEG-room troubleshooting information.
Source = Diagnostics.Source;
fprintf('Live diagnostics\n');
fprintf('  Host/port:              %s / %s\n', local_text(Source.Host), local_text(Source.Port));
fprintf('  Host origin:            %s\n', local_text(Source.SettingOrigin.Host));
fprintf('  Port origin:            %s\n', local_text(Source.SettingOrigin.Port));
fprintf('  Configured buffer path: %s\n', local_text(Source.ResolvedConnection.BufferMPath));
fprintf('  Selected buffer.m:      %s\n', local_text(Source.ResolvedConnection.SelectedBufferFunction));
fprintf('  TestBufferFcn:          %d\n', Source.ResolvedConnection.UsedTestHook);
fprintf('  Fs / expected Fs:       %g / %g\n', Source.Fs, Diagnostics.RTConfig.LiveDryRun.ExpectedFs);
fprintf('  Initial nsamples:       %d\n', Diagnostics.DryRun.InitialNSamples);
fprintf('  Second nsamples:        %d\n', Diagnostics.DryRun.SecondNSamples);
fprintf('  Channel count:          %d\n', Source.NChannels);
fprintf('  First labels:           %s\n', strjoin(Source.ChannelNames(1:min(5, end)), ', '));
fprintf('  Last labels:            %s\n', strjoin(Source.ChannelNames(max(1, end-4):end), ', '));
fprintf('  CTF res4:               %d\n', Source.CTFInfo.HasCTFRes4);
fprintf('  ChannelGains:           %d\n', ~isempty(Source.ChannelGains));
fprintf('  MegRefCoef:             %d\n', ~isempty(Source.MegRefCoef));
fprintf('  Acquisition block:      %s samples\n', local_text(Source.AcquisitionBlockSamples));
fprintf('  MarcConfirmed:          %d\n', Source.CorrectionState.MarcConfirmed);
end

function textValue = local_text(value)
% Convert simple values to text.
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
