function test_prepare_live_combined_matrix_compute_live_errors()
% TEST_PREPARE_LIVE_COMBINED_MATRIX_COMPUTE_LIVE_ERRORS Do not fake ComputeLive.

Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.ComputeLive;
Source = local_source();

didError = false;
try
    nf_prepare_live_combined_matrix(Source, RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'ComputeLive') && contains(ME.message, 'not implemented'), ...
        'Unexpected ComputeLive error: %s', ME.message);
end
assert(didError, 'ComputeLive did not error.');
end

function Source = local_source()
Source = struct();
Source.Fs = 2400;
Source.NChannels = 1;
Source.ChannelNames = {'MEG001'};
Source.ChannelNamesAfterCorrection = {'MEG001'};
Source.HeaderHash = 'header_compute';
Source.CorrectionState = struct();
end
