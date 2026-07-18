function RTConfig = nf_development_session_config()
% NF_DEVELOPMENT_SESSION_CONFIG Build the Step 0 full-chain configuration.
%
% DESCRIPTION:
%     Normal invocation uses a real Psychtoolbox window. Automated tests
%     must explicitly opt into the validated headless test contract.

Modes = nf_modes();
RTConfig = nf_live_config();

RTConfig.Session.Mode = Modes.Session.DevelopmentFullChain;
RTConfig.Session.DevelopmentOnly = true;
RTConfig.Session.ProductionEquivalent = false;
RTConfig.DevelopmentSession.Enabled = true;
RTConfig.DevelopmentSession.DisplayMode = Modes.DevelopmentDisplay.RealPsychtoolbox;

RTConfig.Spatial.Mode = Modes.Spatial.CombinedMatrix;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Spatial.Fallback.Type = Modes.Spatial.FallbackType.RepresentativeDense;

RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.CTF.RemoveBlockMean = false;
RTConfig.Source.FieldTrip.RequireCTFRes4 = false;
RTConfig.Source.FieldTrip.StreamRole = Modes.StreamRole.TestHook;

RTConfig.Feedback.Mode = Modes.Feedback.LocalCircle;
RTConfig.Feedback.Backend = Modes.FeedbackBackend.Psychtoolbox;
RTConfig.Feedback.RequirePsychtoolboxForLive = true;
RTConfig.Feedback.AllowDebugPlotFallback = false;

RTConfig.Protocol.RequireManualStart = true;
RTConfig.Protocol.AllowAutoStartForTestHook = false;
RTConfig.PhaseRunner.ManualStartOwner = Modes.PhaseRunnerOwner.Internal;
RTConfig.PhaseRunner.ResyncOwner = Modes.PhaseRunnerOwner.Internal;

% Permit structural finalization before the stateful producer is constructed.
RTConfig.Source.FieldTrip.TestBufferFcn = @(varargin) [];
RTConfig = nf_finalize_config(RTConfig);
RTConfig.Source.FieldTrip.TestBufferFcn = nf_make_development_fieldtrip_buffer(RTConfig);
RTConfig = nf_finalize_config(RTConfig);

end
