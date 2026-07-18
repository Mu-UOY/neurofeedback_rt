function test_step3d_live_config_defaults()
% TEST_STEP3D_LIVE_CONFIG_DEFAULTS Check exposed Step 3D knobs.

Modes = nf_modes();
RTConfig = nf_live_config();

assert(isempty(RTConfig.Source.FieldTrip.TestBufferFcn), 'Production test hook must be empty.');
assert(strcmp(RTConfig.Source.FieldTrip.AfterManualStartBacklogPolicy, ...
    Modes.BufferBacklog.DiscardAccumulated), 'Unexpected backlog policy default.');
assert(isfield(RTConfig, 'MEGRoom'), 'Missing MEGRoom section.');
assert(strcmp(RTConfig.MEGRoom.SiteLabel, 'BIC_MEG'), 'Unexpected MEG room site label.');
assert(RTConfig.MEGRoom.AllowHistoricalBenDefaults == false, ...
    'Historical Ben defaults should be opt-in.');
assert(isfield(RTConfig, 'LiveSelfTest'), 'Missing LiveSelfTest section.');
assert(isfield(RTConfig, 'LiveResting'), 'Missing LiveResting section.');
assert(isfield(RTConfig, 'LiveTrial'), 'Missing LiveTrial section.');
assert(strcmp(RTConfig.Feedback.Backend, Modes.FeedbackBackend.Psychtoolbox), ...
    'Production feedback backend should default to Psychtoolbox.');
assert(RTConfig.Feedback.LatencyBudgetMs == 25, 'Unexpected latency budget.');
assert(RTConfig.Feedback.LatencySummary.Percentile == 95, ...
    'Unexpected latency summary percentile.');
assert(isempty(RTConfig.DevelopmentSession.TestHooks.SafetyShutdownFcn), ...
    'Production safety shutdown seam must be empty.');
assert(isempty(RTConfig.DevelopmentSession.TestHooks.PauseFcn), ...
    'Production pause seam must be empty.');
assert(RTConfig.Protocol.Trial.MaxFailsafeSeconds >= 15 * 60, ...
    'Trial hard failsafe is too short.');
assert(isfield(Modes, 'FeedbackBackend'), 'Missing FeedbackBackend constants.');
assert(isfield(Modes, 'BufferBacklog'), 'Missing BufferBacklog constants.');
assert(isfield(Modes.StopReason, 'Timeout'), 'Missing timeout stop reason.');
end
