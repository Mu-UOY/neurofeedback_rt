function test_run_validation_segment_bounds_not_double_applied()
% TEST_RUN_VALIDATION_SEGMENT_BOUNDS_NOT_DOUBLE_APPLIED Check replay bounds.

%% ===== CREATE TEMPORARY DATASET =====
% The requested segment starts away from one to expose double-application.
rng(14);
Fs = 1200;
nSamples = 7000;
t = (0:(nSamples - 1)) ./ Fs;
X = sin(2 * pi * 6 * t) + 0.05 * randn(size(t));
ChannelNames = {'CH001'}; %#ok<NASGU>

tmpFile = [tempname, '.mat'];
cleanupObj = onCleanup(@() local_delete_file(tmpFile)); %#ok<NASGU>
save(tmpFile, 'X', 'Fs', 'ChannelNames');

%% ===== CONFIGURE SEGMENTED VALIDATION =====
% The segment length is long enough for a 2 s power window plus filter warmup.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.DatasetPath = tmpFile;
RTConfig.Source.StartSample = 1001;
RTConfig.Source.EndSample = 6500;
RTConfig.Fs = Fs;
RTConfig.Spatial.NChannels = 1;
RTConfig.Spatial.Mode = 'identity';
RTConfig.TargetBand = [4 8];
RTConfig.PowerWindowSamples = round(2.0 * Fs);
RTConfig.BufferSamples = round(4.0 * Fs);
RTConfig.ChunkSamples = round(0.5 * Fs);
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.Brainstorm.Mode = 'skip';

%% ===== RUN VALIDATION =====
% nf_run_validation should replay the trimmed Data.X locally, not reapply
% original acquisition bounds inside nf_source_init.
[Results, Ref, Measures, RTConfigOut] = nf_run_validation(RTConfig);

%% ===== ASSERT RESULT STRUCTURE =====
% Existing Step 1A and Step 2 outputs must still be present.
assert(isfield(Results, 'Step1'));
assert(isfield(Results, 'Compare'));
assert(isfield(Results, 'Band'));
assert(isfield(Results, 'Runtime'));
assert(~isempty(Measures), 'Segmented validation produced no Measures.');
assert(numel(Ref.Power) > 0, 'Segmented validation produced empty Ref.');
assert(isequal(RTConfigOut.Source.StartSample, RTConfig.Source.StartSample));
assert(isequal(RTConfigOut.Source.EndSample, RTConfig.Source.EndSample));

%% ===== ASSERT REPLAY LENGTH =====
% The number of chunks should correspond to the trimmed segment length.
segmentLength = RTConfig.Source.EndSample - RTConfig.Source.StartSample + 1;
assert(Results.NChunks <= ceil(segmentLength / RTConfig.ChunkSamples) + 1, ...
    'Segmented validation appears to have replayed beyond the trimmed segment.');
assert(Results.NChunks > 0, 'Segmented validation produced no chunks.');
assert(Results.NValidMeasures > 0, 'Segmented validation produced no valid Measures.');

end

function local_delete_file(pathToDelete)
if exist(pathToDelete, 'file')
    delete(pathToDelete);
end
end
