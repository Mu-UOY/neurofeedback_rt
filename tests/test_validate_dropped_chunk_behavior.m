function test_validate_dropped_chunk_behavior()
% TEST_VALIDATE_DROPPED_CHUNK_BEHAVIOR Check dropped-chunk validator outcomes.
%
% USAGE:  test_validate_dropped_chunk_behavior()
%
% DESCRIPTION:
%     Exercises no-drop, valid deterministic-drop, and deliberately
%     inconsistent Measure cases for the dropped-chunk behavior validator.

%% ===== NO-DROP CASE =====
% No drop simulation and no flags should pass cleanly.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Filter.Type = 'none';

Measure = nf_measure_empty();
Measure.IsValid = true;
Measure.Power = 1;

Results = nf_validate_dropped_chunk_behavior(Measure, RTConfig);
assert(strcmp(Results.Status, 'PASS'), 'No-drop case should pass.');

%% ===== DETERMINISTIC-DROP CASE =====
% A scheduled drop should produce PASS or WARN, but not FAIL.
[Measures, RTConfig] = local_run_scheduled_drop();
Results = nf_validate_dropped_chunk_behavior(Measures, RTConfig);
assert(~strcmp(Results.Status, 'FAIL'), 'Valid deterministic-drop case should not fail.');

%% ===== INCONSISTENT MEASURE CASE =====
% A Measure cannot be valid and gap-contaminated at the same time.
BadMeasure = nf_measure_empty();
BadMeasure.GapInWindowFlag = true;
BadMeasure.IsValid = true;

Results = nf_validate_dropped_chunk_behavior(BadMeasure, RTConfig);
assert(strcmp(Results.Status, 'FAIL'), 'Inconsistent valid/gap Measure should fail.');

end

function [Measures, RTConfig] = local_run_scheduled_drop()
% Run a small in-memory stream with one scheduled drop.
Fs = 100;
nSamples = 500;
t = (0:(nSamples - 1)) ./ Fs;
Data = struct();
Data.X = sin(2 .* pi .* 10 .* t);
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001'};
Data.Events = [];

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Filter.Type = 'none';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 1;
RTConfig.TargetBand = [8 12];
RTConfig.ChunkSamples = 20;
RTConfig.PowerWindowSamples = 60;
RTConfig.BufferSamples = 100;
RTConfig.Simulation.EnableDroppedChunks = true;
RTConfig.Simulation.DropChunkIndices = [3];

Source = nf_source_init('simulated_online', Data, RTConfig);
RT = nf_rt_prepare(RTConfig);

Measures = repmat(nf_measure_empty(), 1, 0);
while nf_source_has_next(Source)
    [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end
    [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig); %#ok<ASGLU>
    Measures(end + 1) = Measure; %#ok<AGROW>
end
end
