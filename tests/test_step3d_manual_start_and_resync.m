function test_step3d_manual_start_and_resync()
% TEST_STEP3D_MANUAL_START_AND_RESYNC Check no-wait, auto-start, and backlog policy.

Modes = nf_modes();
[RTConfig, tempRoot] = nf_test_live_self_test_config();
cleanupObj = onCleanup(@() local_cleanup(tempRoot));

RTConfig.Protocol.RequireManualStart = false;
WaitResult = nf_wait_for_manual_start(RTConfig, Modes.Session.LiveResting);
assert(WaitResult.Waited == false, 'Manual-start no-wait path waited.');

RTConfig.Protocol.RequireManualStart = true;
RTConfig.Protocol.AllowAutoStartForTestHook = true;
WaitResult = nf_wait_for_manual_start(RTConfig, Modes.Session.LiveTrial);
assert(WaitResult.AutoStarted == true, 'Test-hook auto-start did not trigger.');

Source = local_source(1000);
[Source2, Info] = nf_source_resync_after_pause(Source, RTConfig, Modes.Session.LiveTrial);
assert(Info.Applied == true, 'Discard policy did not apply.');
assert(Source2.LastSampleRead >= Source.LastSampleRead, 'Source cursor moved backwards.');
assert(Info.SkippedSamples >= 0, 'Skipped samples negative.');

RTConfig.Source.FieldTrip.AfterManualStartBacklogPolicy = Modes.BufferBacklog.PreserveCursor;
[Source3, Info2] = nf_source_resync_after_pause(Source, RTConfig, Modes.Session.LiveTrial);
assert(Info2.Applied == false, 'PreserveCursor should not apply discard.');
assert(Source3.LastSampleRead == Source.LastSampleRead, 'PreserveCursor modified source cursor.');

clear cleanupObj
end

function Source = local_source(lastSample)
Source = struct();
Source.Mode = 'live_fieldtrip';
Source.LiveAdapter = 'ben_fieldtrip_buffer';
Source.Fs = 2400;
Source.NChannels = 3;
Source.ChannelNames = {'MEG001','MEG002','MEG003'};
Source.ChannelNamesAfterCorrection = Source.ChannelNames;
Source.LastSampleRead = lastSample;
Source.InitialSample = lastSample;
Source.Header = struct('NSamples', lastSample);
end

function local_cleanup(tempRoot)
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
