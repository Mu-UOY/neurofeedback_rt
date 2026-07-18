function test_step0_room_representative_workload()
% TEST_STEP0_ROOM_REPRESENTATIVE_WORKLOAD Run the room-shaped full chain.

RTConfig = nf_test_step0_config(tempname, true);
input = RTConfig.DevelopmentSession.Input;
assert(input.TotalChannelCount == ...
    input.PrimaryMEGChannelCount + input.ReferenceMEGChannelCount);
primary = nf_ctf275_primary_channel_names();
reference = nf_step0_provisional_reference_channel_names(RTConfig);
assert(numel(primary) == input.PrimaryMEGChannelCount);
assert(numel(reference) == input.ReferenceMEGChannelCount);
assert(input.ReferenceLabelsAreProvisional);
[Result, Source, Spatial, Logger] = nf_run_development_full_chain(RTConfig);
expectedSize = [RTConfig.DevelopmentSession.Matrix.OutputRowUpperBound, ...
    input.TotalChannelCount];
expectedLabels = [primary, reference];
assert(Result.Pass && Result.Completed && Logger.Closed);
assert(isequal(Source.ChannelNames, expectedLabels));
assert(isequal(size(Spatial.CombinedMatrix), expectedSize));
assert(strcmp(class(Spatial.CombinedMatrix), ...
    RTConfig.DevelopmentSession.Matrix.NumericClass));
assert(strcmp(Spatial.Orientation, RTConfig.DevelopmentSession.Matrix.Orientation));
assert(Spatial.RequestedDensity == RTConfig.DevelopmentSession.Matrix.Density);
assert(abs(Spatial.RealizedDensity - Spatial.RequestedDensity) < eps);
assert(Spatial.IsTechnicalFallback && ~Spatial.IsIPS && ~Result.ProductionEquivalent);
assert(strcmp(Spatial.MatrixSource, RTConfig.Spatial.MatrixSource));
assert(strcmp(Result.RestingResult.SpatialHash, Spatial.Hash));
assert(strcmp(Result.TrialResult.SpatialHash, Spatial.Hash));
assert(Result.SpatialSummary.SameHashAcrossPhases);
assert(isequal(Result.RestingResult.SpatialSize, expectedSize));
assert(isequal(Result.TrialResult.SpatialSize, expectedSize));
assert(isequal(Result.RestingResult.SpatialInputChannelNames, expectedLabels));
assert(isequal(Result.TrialResult.SpatialInputChannelNames, expectedLabels));
assert(Result.TrialResult.NValidMeasures >= 1);
assert(Result.FeedbackAudit.NCompletedFlips >= 1);
assert(Result.FeedbackAudit.UsesHeadlessPsychtoolboxTest);

%% ===== PROVE CONFIGURED PROCESSING AND LIFECYCLE CONTRACT =====
Modes = nf_modes();
assert(RTConfig.ChunkSamples == RTConfig.Fs .* RTConfig.ChunkSeconds);
assert(RTConfig.PowerWindowSamples == ...
    RTConfig.Fs .* RTConfig.PowerWindowSeconds);
assert(strcmp(RTConfig.Filter.Type, Modes.Filter.IIRSOS));
filterState = nf_rt_filter_init(RTConfig, size(Spatial.CombinedMatrix, 1));
assert(strcmp(filterState.Type, RTConfig.Filter.Type));
assert(isfield(filterState, 'SOS') && ~isempty(filterState.SOS));
assert(strcmp(Result.StopReason, Modes.StopReason.Success));
assert(Result.BaselineQuality.Pass && Result.BaselineReloaded);
assert(startsWith(Result.BaselinePath, Result.SessionOutputDir));
assert(strcmp(Result.BaselineConfigHash, Result.TrialBaselineConfigHash));
assert(strcmp(Result.TrialBaselineConfigHash, ...
    Result.TrialResult.BaselineConfigHash));

savedBaseline = load(Result.BaselinePath, 'Baseline');
loadConfig = RTConfig;
loadConfig.Baseline.Path = Result.BaselinePath;
loadConfig.Feedback.Mode = savedBaseline.Baseline.ConfigHashInputs.FeedbackMode;
publicBaseline = nf_load_baseline(loadConfig);
assert(strcmp(publicBaseline.ConfigHash, Result.BaselineConfigHash));

expectedFeedbackUpdates = floor(Result.TrialResult.NValidMeasures ./ ...
    RTConfig.Feedback.UpdateEveryNValidMeasures);
assert(Result.TrialResult.NFeedbackUpdates == expectedFeedbackUpdates);
assert(Logger.NMeasures == Result.RestingResult.NChunks + ...
    Result.TrialResult.NChunks);
assert(numel(Logger.ChunkMeta) == Logger.NMeasures);

%% ===== PROVE MATRIX DETERMINISM, RNG RESTORATION, AND SPARSE REPAIR =====
rngBefore = rng;
repeatSpatial = nf_prepare_live_combined_matrix(Source, RTConfig);
rngAfter = rng;
assert(isequal(rngBefore, rngAfter));
assert(isequal(repeatSpatial.CombinedMatrix, Spatial.CombinedMatrix));
assert(strcmp(repeatSpatial.Hash, Spatial.Hash));

sparseConfig = RTConfig;
sparseConfig.DevelopmentSession.Matrix.Density = ...
    1 ./ sparseConfig.DevelopmentSession.Input.TotalChannelCount;
rngBeforeSparse = rng;
sparseSpatial = nf_prepare_live_combined_matrix(Source, sparseConfig);
assert(isequal(rngBeforeSparse, rng));
assert(all(any(sparseSpatial.CombinedMatrix ~= 0, 2)));
assert(sparseSpatial.RequestedDensity == ...
    sparseConfig.DevelopmentSession.Matrix.Density);
end
