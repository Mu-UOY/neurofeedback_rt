function RTConfig = nf_mock_live_test_config()
% NF_MOCK_LIVE_TEST_CONFIG Build a finalized hardware-free mock-live config.
%
% DESCRIPTION:
%     Creates config only. It does not implement a mock-live source adapter or
%     produce chunks.

Modes = nf_modes();
RTConfig = nf_live_config();

RTConfig.Source.Mode = Modes.Source.MockLiveBuffer;
RTConfig.Source.LiveAdapter = Modes.LiveAdapter.MockBuffer;

RTConfig.Feedback.AllowDebugPlotFallback = true;
RTConfig.Feedback.RequirePsychtoolboxForLive = false;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.DebugPlot;

RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;

RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.FieldTrip.RequireCTFRes4 = false;

RTConfig = nf_finalize_config(RTConfig);

end
