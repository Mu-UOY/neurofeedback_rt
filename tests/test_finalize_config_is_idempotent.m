function test_finalize_config_is_idempotent()
% TEST_FINALIZE_CONFIG_IS_IDEMPOTENT Check repeated finalization.

%% ===== BUILD UNFINALIZED MOCK-LIVE CONFIG INLINE =====
% Do not call fake helper names from earlier planning drafts.
Modes = nf_modes();
RTConfig = nf_live_config();

RTConfig.Debug.Verbose = false;
RTConfig.Source.Mode = Modes.Source.MockLiveBuffer;
RTConfig.Source.LiveAdapter = Modes.LiveAdapter.MockBuffer;
RTConfig.Feedback.AllowDebugPlotFallback = true;
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.FieldTrip.RequireCTFRes4 = false;
RTConfig.Internal.IsFinalized = false;

%% ===== FINALIZE TWICE =====
% Meaningful finalized values should remain stable.
C1 = nf_finalize_config(RTConfig);
C2 = nf_finalize_config(C1);

assert(C2.Internal.IsFinalized == C1.Internal.IsFinalized, ...
    'Finalization state changed on second finalize.');
assert(C2.Fs == C1.Fs, 'Fs changed on second finalize.');
assert(C2.ChunkSamples == C1.ChunkSamples, 'ChunkSamples changed on second finalize.');
assert(C2.PowerWindowSamples == C1.PowerWindowSamples, ...
    'PowerWindowSamples changed on second finalize.');
assert(C2.BufferSamples == C1.BufferSamples, ...
    'BufferSamples changed on second finalize.');
assert(C2.Protocol.Trial.MaxFailsafeSeconds == C1.Protocol.Trial.MaxFailsafeSeconds, ...
    'Trial hard failsafe changed on second finalize.');
assert(C2.Source.FieldTrip.RequireCTFRes4 == C1.Source.FieldTrip.RequireCTFRes4, ...
    'RequireCTFRes4 changed on second finalize.');

end
