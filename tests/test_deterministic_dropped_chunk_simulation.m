function test_deterministic_dropped_chunk_simulation()
% TEST_DETERMINISTIC_DROPPED_CHUNK_SIMULATION Check scheduled source drops.
%
% USAGE:  test_deterministic_dropped_chunk_simulation()
%
% DESCRIPTION:
%     Runs an in-memory simulated-online stream with a deterministic dropped
%     chunk and verifies that the next emitted real chunk carries gap metadata.

%% ===== RUN SCHEDULED DROP STREAM =====
% Drop chunk 3 so the first full power window is gap-contaminated.
[Measures, RT, RTConfig] = local_run_stream_with_drop_schedule([3]);

%% ===== CHECK GAP BEHAVIOR =====
% A deterministic drop should invalidate at least one gapped Measure.
gapOrDropped = [Measures.GapInWindowFlag] | [Measures.DroppedChunkFlag];
assert(any(gapOrDropped), 'No Measure carried gap or dropped-chunk flags.');
assert(any(gapOrDropped & ~[Measures.IsValid]), 'No gapped/dropped Measure was invalid.');
assert(any(strcmp({Measures.InvalidReason}, 'gap_in_window')), ...
    'Expected at least one gap_in_window invalid reason.');
assert(RT.SampleCounter.TotalDroppedSamples >= RTConfig.ChunkSamples, ...
    'TotalDroppedSamples did not record the deterministic dropped chunk.');

%% ===== CHECK VALIDATOR =====
% The robust validator should pass or warn, but not fail, for a valid drop.
Results = nf_validate_dropped_chunk_behavior(Measures, RTConfig);
assert(~strcmp(Results.Status, 'FAIL'), 'Dropped-chunk validator failed a valid scheduled drop.');

%% ===== CHECK DETERMINISTIC RESET REPLAY =====
% Reset must restart the chunk counter and reproduce the scheduled gap.
local_check_scheduled_reset_replay();

%% ===== CHECK SEEDED PROBABILISTIC REPRODUCIBILITY =====
% With no deterministic schedule, a finite RandomSeed should repeat the pattern.
patternA = local_probabilistic_drop_pattern(42);
patternB = local_probabilistic_drop_pattern(42);
assert(isequal(patternA.SampleIndex, patternB.SampleIndex), ...
    'Seeded probabilistic source emitted different sample indices.');
assert(isequal(patternA.GapBeforeChunkFlag, patternB.GapBeforeChunkFlag), ...
    'Seeded probabilistic source emitted different gap flags.');

%% ===== CHECK SEEDED PROBABILISTIC RESET REPLAY =====
% A reset source should reproduce the same seeded probabilistic sequence.
local_check_probabilistic_reset_replay();

%% ===== CHECK RANDOM SEED VALIDATION =====
% Negative seeds are invalid because they cannot define a stable rng state.
local_check_negative_random_seed_rejected();

end

function [Measures, RT, RTConfig] = local_run_stream_with_drop_schedule(dropChunkIndices)
% Run the source and RT loop directly without any MAT file.
[Data, RTConfig] = local_synthetic_data_and_config();
RTConfig.Simulation.EnableDroppedChunks = true;
RTConfig.Simulation.DropChunkIndices = dropChunkIndices;

Source = nf_source_init('simulated_online', Data, RTConfig);
RT = nf_rt_prepare(RTConfig);

Measures = repmat(nf_measure_empty(), 1, 0);
while nf_source_has_next(Source)
    [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end
    [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig);
    Measures(end + 1) = Measure; %#ok<AGROW>
end
end

function Pattern = local_probabilistic_drop_pattern(seed)
% Collect emitted sample indices and gap flags for a seeded probabilistic run.
[Data, RTConfig] = local_synthetic_data_and_config();
RTConfig.Simulation.EnableDroppedChunks = true;
RTConfig.Simulation.DropChunkIndices = [];
RTConfig.Simulation.DropProbability = 0.35;
RTConfig.Simulation.RandomSeed = seed;

Source = nf_source_init('simulated_online', Data, RTConfig);
sampleIndex = [];
gapFlag = [];
while nf_source_has_next(Source)
    [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end
    sampleIndex(end + 1) = chunk.SampleIndex; %#ok<AGROW>
    gapFlag(end + 1) = chunk.GapBeforeChunkFlag; %#ok<AGROW>
end

Pattern = struct();
Pattern.SampleIndex = sampleIndex;
Pattern.GapBeforeChunkFlag = gapFlag;
end

function local_check_scheduled_reset_replay()
% Verify reset restarts deterministic drop scheduling from chunk one.
[Data, RTConfig] = local_synthetic_data_and_config();
RTConfig.Simulation.EnableDroppedChunks = true;
RTConfig.Simulation.DropChunkIndices = [3];

Source = nf_source_init('simulated_online', Data, RTConfig);

[~, Source] = nf_get_meg_chunk(Source, RTConfig);
[~, Source] = nf_get_meg_chunk(Source, RTConfig);
[chunkAfterDrop, Source] = nf_get_meg_chunk(Source, RTConfig);

firstReplayGapSample = chunkAfterDrop.SampleIndex;
assert(chunkAfterDrop.GapBeforeChunkFlag, ...
    'Expected scheduled drop to produce a gap before the emitted chunk.');
assert(Source.ChunkCounter > 0, 'ChunkCounter did not advance before reset.');

Source = nf_source_reset(Source);
assert(Source.ChunkCounter == 0, 'nf_source_reset did not reset Source.ChunkCounter.');
assert(Source.LastDroppedChunks == 0, 'nf_source_reset did not reset LastDroppedChunks.');
assert(Source.LastDroppedSamples == 0, 'nf_source_reset did not reset LastDroppedSamples.');

[~, Source] = nf_get_meg_chunk(Source, RTConfig);
[~, Source] = nf_get_meg_chunk(Source, RTConfig);
[chunkAfterDropB, Source] = nf_get_meg_chunk(Source, RTConfig); %#ok<ASGLU>

assert(chunkAfterDropB.SampleIndex == firstReplayGapSample, ...
    'nf_source_reset did not reset deterministic drop schedule.');
assert(chunkAfterDropB.GapBeforeChunkFlag, ...
    'Reset source replay did not reproduce scheduled drop gap.');
end

function local_check_probabilistic_reset_replay()
% Verify reset reuses RandomSeed for reproducible probabilistic drop patterns.
[Data, RTConfig] = local_synthetic_data_and_config();
RTConfig.Simulation.EnableDroppedChunks = true;
RTConfig.Simulation.DropChunkIndices = [];
RTConfig.Simulation.DropProbability = 0.35;
RTConfig.Simulation.RandomSeed = 42;

Source = nf_source_init('simulated_online', Data, RTConfig);
[PatternA, Source] = local_collect_emitted_pattern(Source, RTConfig, 8);
assert(numel(PatternA.SampleIndex) == 8, 'First probabilistic replay emitted too few chunks.');

Source = nf_source_reset(Source);
assert(Source.ChunkCounter == 0, 'nf_source_reset did not reset ChunkCounter before seeded replay.');
[PatternB, Source] = local_collect_emitted_pattern(Source, RTConfig, 8); %#ok<ASGLU>
assert(numel(PatternB.SampleIndex) == 8, 'Second probabilistic replay emitted too few chunks.');

assert(isequal(PatternA.SampleIndex, PatternB.SampleIndex), ...
    'nf_source_reset did not reproduce seeded probabilistic sample-index pattern.');
assert(isequal(PatternA.GapBeforeChunkFlag, PatternB.GapBeforeChunkFlag), ...
    'nf_source_reset did not reproduce seeded probabilistic gap pattern.');
end

function [Pattern, Source] = local_collect_emitted_pattern(Source, RTConfig, nEmitted)
% Collect a fixed number of nonempty emitted chunks from a source.
sampleIndex = [];
gapFlag = [];
while nf_source_has_next(Source) && numel(sampleIndex) < nEmitted
    [chunk, Source] = nf_get_meg_chunk(Source, RTConfig);
    if isempty(chunk) || chunk.NSamples == 0
        continue;
    end
    sampleIndex(end + 1) = chunk.SampleIndex; %#ok<AGROW>
    gapFlag(end + 1) = chunk.GapBeforeChunkFlag; %#ok<AGROW>
end

Pattern = struct();
Pattern.SampleIndex = sampleIndex;
Pattern.GapBeforeChunkFlag = gapFlag;
end

function local_check_negative_random_seed_rejected()
% Config validation should reject negative RNG seeds.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Filter.Type = 'none';
RTConfig.Spatial.NChannels = 1;
RTConfig.Simulation.RandomSeed = -1;

didError = false;
try
    nf_check_config(RTConfig);
catch ME
    didError = contains(ME.message, 'RandomSeed');
end
assert(didError, 'Negative RandomSeed was not rejected by nf_check_config.');
end

function [Data, RTConfig] = local_synthetic_data_and_config()
% Create a small deterministic target-band dataset and compatible config.
Fs = 100;
nSamples = 500;
t = (0:(nSamples - 1)) ./ Fs;
Data = struct();
Data.X = [
    sin(2 .* pi .* 10 .* t)
    0.5 .* sin(2 .* pi .* 10 .* t + 0.2)
];
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001','CH002'};
Data.Events = [];

RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Filter.Type = 'none';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 2;
RTConfig.TargetBand = [8 12];
RTConfig.ChunkSamples = 20;
RTConfig.PowerWindowSamples = 60;
RTConfig.BufferSamples = 100;
RTConfig.Source.Mode = 'simulated_online';
RTConfig.Source.DatasetPath = '';
RTConfig.Source.StartSample = 1;
RTConfig.Source.EndSample = Inf;
end
