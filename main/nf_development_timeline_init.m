function Timeline = nf_development_timeline_init(RTConfig, sessionOutputDir)
% NF_DEVELOPMENT_TIMELINE_INIT Initialize and durably write a Step 0 timeline.

Timeline = struct();
Timeline.StartedTic = tic;
Timeline.Events = struct([]);
Timeline.Path = fullfile(sessionOutputDir, ...
    RTConfig.DevelopmentSession.Output.TimelineFilename);
[~, Timeline.RunID] = fileparts(sessionOutputDir);
Timeline.TempSuffix = RTConfig.DevelopmentSession.Output.AtomicTempSuffix;
Timeline = nf_development_timeline_append(Timeline, ...
    nf_modes().TimelineEvent.SessionStart, '', NaN, NaN, ...
    'Development full-chain session started.', false);

end
