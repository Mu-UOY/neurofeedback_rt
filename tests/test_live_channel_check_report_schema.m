function test_live_channel_check_report_schema()
% TEST_LIVE_CHANNEL_CHECK_REPORT_SCHEMA Check report files and session ownership.

%% ===== SAVE REPORT INTO EXISTING SESSION =====
RTConfig = nf_live_config();
tempProjectRoot = tempname;
mkdir(tempProjectRoot);
cleanupObj = onCleanup(@() rmdir(tempProjectRoot, 's')); %#ok<NASGU>
RTConfig.Paths.ProjectRoot = tempProjectRoot;

Session = nf_make_session_output_dir(RTConfig, 'live_channel_check');
Check = local_fake_check(Session);

Paths = nf_save_live_channel_check(Check, RTConfig, Session);

assert(exist(Paths.MatPath, 'file') == 2, 'MAT report missing.');
assert(exist(Paths.TextPath, 'file') == 2, 'TXT report missing.');
assert(exist(Paths.ChannelCsvPath, 'file') == 2, 'Channel CSV missing.');
assert(strcmp(fileparts(Paths.MatPath), Session.ReportsDir), 'MAT report outside ReportsDir.');

liveRoot = fullfile(tempProjectRoot, 'outputs', 'live');
sessions = dir(liveRoot);
sessions = sessions([sessions.isdir] & ~ismember({sessions.name}, {'.','..'}));
assert(numel(sessions) == 1, 'Save helper created an extra session folder.');

T = readtable(Paths.ChannelCsvPath);
assert(strcmp(T.ChannelName{1}, 'MEG001'), 'Channel CSV did not contain labels.');

end

function Check = local_fake_check(Session)
% Build a minimal PASS-like channel check struct.
Check.Status = 'PASS';
Check.Pass = true;
Check.Host = 'test-host';
Check.Port = 1;
Check.SettingOrigin.Host = 'test_hook';
Check.SettingOrigin.Port = 'test_hook';
Check.ResolvedConnection.SelectedBufferFunction = 'test_hook';
Check.ResolvedConnection.AllBufferCandidates = {};
Check.PathInfo.AllBufferPaths = {};
Check.PathInfo.BufferShadowingDetected = false;
Check.PathInfo.BufferLooksLikeMatlabToolbox = false;
Check.Header = struct();
Check.RawHeaderSummary = struct();
Check.Fs = 2400;
Check.ExpectedFs = 2400;
Check.FsMatches = true;
Check.NChannels = 2;
Check.InitialNSamples = 1000;
Check.SecondNSamples = 1480;
Check.SampleCountAdvanced = true;
Check.AcquisitionBlockSamples = 480;
Check.AcquisitionBlockSeconds = 0.2;
Check.HasCTFRes4 = false;
Check.HasChannelGains = false;
Check.HasMegRefCoef = false;
Check.CorrectionState.MarcConfirmed = false;
Check.ChannelNames = {'MEG001','MEG002'};
Check.ChannelNamesAfterCorrection = {'MEG001','MEG002'};
Check.OutputDir = Session.ReportsDir;
Check.ReportPaths = struct();
Check.BenIndexingNote = 'Ben indexing note.';
Check.Recommendation = 'ok';
Check.Messages = {};
Check.Error = struct();
end
