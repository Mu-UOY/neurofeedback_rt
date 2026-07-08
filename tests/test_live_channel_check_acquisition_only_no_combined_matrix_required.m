function test_live_channel_check_acquisition_only_no_combined_matrix_required()
% TEST_LIVE_CHANNEL_CHECK_ACQUISITION_ONLY_NO_COMBINED_MATRIX_REQUIRED Check scope.

%% ===== FINALIZE LIVE CHANNEL CHECK WITHOUT MATRIX PATH =====
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Source.FieldTrip.TestBufferFcn = @(varargin) [];
RTConfig.Session.Mode = Modes.Session.LiveChannelCheck;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = '';
RTConfig.Source.FieldTrip.RequireCTFRes4 = [];

RTConfig = nf_finalize_config(RTConfig);

assert(strcmp(RTConfig.Session.Mode, Modes.Session.LiveChannelCheck), ...
    'Live channel check session mode changed.');
assert(isempty(RTConfig.Spatial.CombinedMatrixPath), ...
    'Acquisition-only live channel check should not require a matrix path.');

end
