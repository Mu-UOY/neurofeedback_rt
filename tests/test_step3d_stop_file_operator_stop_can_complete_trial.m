function test_step3d_stop_file_operator_stop_can_complete_trial()
% TEST_STEP3D_STOP_FILE_OPERATOR_STOP_CAN_COMPLETE_TRIAL Document stop-file semantics.

%% ===== PREPARE STOP-FILE TRIAL =====
% Stop-file is treated as an operator/manual stop, not a non-pass abort.
Modes = nf_modes();
[RTConfig, tempRoot] = nf_test_live_self_test_config();
stopPath = [tempname, '.stop'];
cleanupObj = onCleanup(@() local_cleanup(tempRoot, stopPath));

RTConfig.Source.FieldTrip.TestBufferFcn = local_stop_file_buffer(stopPath, 12);
RTConfig.Source.FieldTrip.AfterManualStartBacklogPolicy = Modes.BufferBacklog.DiscardAccumulated;
RTConfig.Source.CTF.RemoveBlockMean = false;
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Protocol.Trial.Success.Enabled = false;
RTConfig.LiveTrial.RequireAtLeastOneValidMeasure = true;
RTConfig.LiveTrial.RequireAtLeastOneFeedbackUpdate = true;
RTConfig.Feedback.Mode = Modes.Feedback.DebugValue;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.None;
RTConfig.Feedback.MapSource = 'ZSmoothed';
RTConfig.Feedback.UpdateEveryNValidMeasures = 1;
RTConfig.Safety.EnableStopFile = true;
RTConfig.Safety.StopFilePath = stopPath;
RTConfig.Safety.EnableKeyboardStop = false;

Baseline = local_baseline(RTConfig);

%% ===== RUN TRIAL =====
TrialResult = nf_run_live_trial(RTConfig, [], [], Baseline);

assert(strcmp(TrialResult.StopReason, Modes.StopReason.StopFile), ...
    'Stop file did not produce stop_file stop reason.');
assert(TrialResult.NValidMeasures >= 1, 'Stop-file trial had no valid measures.');
assert(TrialResult.NFeedbackUpdates >= 1, 'Stop-file trial had no feedback updates.');
assert(TrialResult.NFiniteZSmoothed >= 1, 'Stop-file trial had no finite smoothed z-score.');
assert(TrialResult.Pass == true, 'Operator stop-file should not force trial failure.');
assert(TrialResult.Completed == true, 'Operator stop-file should allow completion.');
assert(TrialResult.FeedbackClosed == true, 'Feedback cleanup did not complete.');
assert(TrialResult.SafetyClosed == true, 'Safety cleanup did not complete.');
assert(TrialResult.LoggerClosed == true, 'Owned logger was not closed.');

clear cleanupObj
end

function fcn = local_stop_file_buffer(stopPath, stopAfterGetDatCalls)
% Return a fake FieldTrip buffer that requests stop after enough real chunks.
state = struct();
state.HeaderCalls = 0;
state.GetDatCalls = 0;
state.Fs = 2400;
state.NChannels = 3;
state.InitialSamples = 1000;
state.MaxSamples = 250000;
state.ChannelNames = {'MEG001','MEG002','MEG003'};

fcn = @local_call;

    function out = local_call(command, arg, varargin) %#ok<INUSD>
        switch char(command)
            case 'get_hdr'
                state.HeaderCalls = state.HeaderCalls + 1;
                out = local_header(state, state.InitialSamples + 480 * state.HeaderCalls);

            case 'wait_dat'
                requestedStop = arg(1);
                out = local_header(state, max(requestedStop, state.InitialSamples));

            case 'get_dat'
                state.GetDatCalls = state.GetDatCalls + 1;
                sampleRange = arg(1):arg(2);
                out = struct();
                out.buf = local_data(state, sampleRange);
                if state.GetDatCalls >= stopAfterGetDatCalls
                    local_write_stop_file(stopPath);
                end

            otherwise
                error('Unsupported test buffer command: %s', command);
        end
    end
end

function hdr = local_header(state, nsamples)
% Build a minimal FieldTrip header.
hdr = struct();
hdr.fsample = state.Fs;
hdr.nsamples = min(state.MaxSamples, round(nsamples));
hdr.nchans = state.NChannels;
hdr.channel_names = state.ChannelNames;
end

function X = local_data(state, sampleRange)
% Return finite target-band data that produces valid trial measures.
t = double(sampleRange(:)') ./ state.Fs;
target = sin(2 .* pi .* 6 .* t);
X = zeros(state.NChannels, numel(sampleRange));
X(1, :) = target;
X(2, :) = 0.05 .* sin(2 .* pi .* 30 .* t);
X(3, :) = 0.02 .* cos(2 .* pi .* 1 .* t);
end

function local_write_stop_file(stopPath)
% Create the configured operator stop file.
fid = fopen(stopPath, 'w');
assert(fid > 0, 'Could not create temporary stop file.');
fprintf(fid, 'stop\n');
fclose(fid);
end

function Baseline = local_baseline(RTConfig)
% Build a finalized, nondegenerate baseline for trial z-scoring.
values = 1:RTConfig.Baseline.MinValidWindows;
Baseline = struct();
Baseline.Type = 'baseline';
Baseline.Partial = false;
Baseline.Finalized = true;
Baseline.Mean = 0;
Baseline.Std = 1;
Baseline.Values = values;
Baseline.TrimmedValues = values;
Baseline.ValidWindowCount = numel(values);
Baseline.UsableWindowCount = numel(values);
end

function local_cleanup(tempRoot, stopPath)
% Remove temporary test artifacts.
if exist(stopPath, 'file') == 2
    delete(stopPath);
end
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end
