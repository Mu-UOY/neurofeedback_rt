function [TransitionResult, Source, Timeline] = ...
    nf_run_development_transition(RTConfig, Source, Timeline)
% NF_RUN_DEVELOPMENT_TRANSITION Run the bounded Step 0 manual transition.

Modes = nf_modes();
previousSample = local_current_sample(Source);
TransitionResult = local_empty_result(previousSample);
Timeline = nf_development_timeline_append(Timeline, ...
    Modes.TimelineEvent.TransitionWaitStart, Modes.Phase.Transition, ...
    previousSample, previousSample, 'Manual transition wait started.', false);

transitionConfig = RTConfig;
transitionConfig.Protocol.ManualStartMaxWaitSeconds = ...
    RTConfig.DevelopmentSession.Transition.MaxPauseSeconds;
TransitionResult.WaitResult = nf_wait_for_manual_start( ...
    transitionConfig, Modes.Phase.Transition);
Timeline = nf_development_timeline_append(Timeline, ...
    Modes.TimelineEvent.TransitionWaitEnd, Modes.Phase.Transition, ...
    previousSample, previousSample, 'Manual transition wait ended.', false);

if TransitionResult.WaitResult.TimedOut
    TransitionResult.StopReason = Modes.StopReason.TransitionTimeout;
    TransitionResult.TimedOut = true;
    Timeline = nf_development_timeline_append(Timeline, ...
        Modes.TimelineEvent.TransitionTimeout, Modes.Phase.Transition, ...
        previousSample, previousSample, 'Transition exceeded its strict maximum.', true);
    return;
end

try
    nf_development_maybe_inject_failure(RTConfig, ...
        Modes.DevelopmentFailure.Transition, 1);
    if nf_is_strict_step0_headless_contract(RTConfig)
        nf_live_buffer_call(RTConfig, Modes.TestBufferCommand.Advance, ...
            RTConfig.DevelopmentSession.Transition.TestAdvanceSamples);
    end
    [Source, resync] = nf_source_resync_after_pause(Source, RTConfig, Modes.Phase.Transition);
    TransitionResult.ResyncInfo = resync;
    TransitionResult = local_set_range(TransitionResult, previousSample, resync.LatestSample);
    TransitionResult.Pass = true;
    TransitionResult.Completed = true;
    Timeline = nf_development_timeline_append(Timeline, ...
        Modes.TimelineEvent.TransitionResync, Modes.Phase.Transition, ...
        previousSample, resync.LatestSample, resync.Message, false);
    Timeline = nf_development_timeline_append(Timeline, ...
        Modes.TimelineEvent.TransitionBacklogDiscarded, Modes.Phase.Transition, ...
        TransitionResult.SkippedFirstSample, TransitionResult.SkippedLastSample, ...
        sprintf('Discarded %g transition samples.', TransitionResult.SkippedSampleCount), false);
catch ME
    TransitionResult.StopReason = Modes.StopReason.Error;
    TransitionResult.Error = ME.message;
    TransitionResult.ErrorIdentifier = ME.identifier;
    TransitionResult.ErrorReport = local_error_report(ME);
end

end

function Result = local_empty_result(previousSample)
Result = struct('Started', true, 'Completed', false, 'Pass', false, ...
    'TimedOut', false, 'StopReason', '', 'PreviousSample', previousSample, ...
    'LatestSample', NaN, 'RangeKnown', false, 'NoSamplesSkipped', false, ...
    'SkippedFirstSample', NaN, 'SkippedLastSample', NaN, ...
    'SkippedSampleCount', NaN, 'WaitResult', struct(), 'ResyncInfo', struct(), ...
    'Error', '', 'ErrorIdentifier', '', 'ErrorReport', '');
end

function report = local_error_report(ME)
try
    report = getReport(ME, 'extended', 'hyperlinks', 'off');
catch
    report = ME.message;
end
end

function Result = local_set_range(Result, previousSample, latestSample)
Result.LatestSample = latestSample;
if isfinite(previousSample) && isfinite(latestSample) && latestSample >= previousSample
    Result.RangeKnown = true;
    Result.SkippedSampleCount = latestSample - previousSample;
    if Result.SkippedSampleCount == 0
        Result.NoSamplesSkipped = true;
    else
        Result.SkippedFirstSample = previousSample + 1;
        Result.SkippedLastSample = latestSample;
        if Result.SkippedSampleCount ~= ...
                Result.SkippedLastSample - Result.SkippedFirstSample + 1
            error('Step 0 skipped-range inclusive invariant failed.');
        end
    end
end
end

function sample = local_current_sample(Source)
sample = NaN;
if isstruct(Source) && isfield(Source, 'LastSampleRead') && ...
        isnumeric(Source.LastSampleRead) && isscalar(Source.LastSampleRead)
    sample = double(Source.LastSampleRead);
end
end
