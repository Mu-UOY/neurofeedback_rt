function test_live_rt_dry_run_requires_spatial_for_precomputed_empty_path()
% TEST_LIVE_RT_DRY_RUN_REQUIRES_SPATIAL_FOR_PRECOMPUTED_EMPTY_PATH Check path rule.

Modes = nf_modes();

RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Session.Mode = Modes.Session.LiveRTDryRun;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = '';
RTConfig.Source.FieldTrip.TestBufferFcn = @local_buffer;

didError = false;
try
    nf_finalize_config(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'CombinedMatrixPath'), ...
        'Unexpected missing path error: %s', ME.message);
end
assert(didError, 'LiveRTDryRun allowed Precomputed with empty CombinedMatrixPath.');

RTConfig.Session.Mode = Modes.Session.LiveChunkSmokeTest;
RTConfig = nf_finalize_config(RTConfig);
assert(strcmp(RTConfig.Session.Mode, Modes.Session.LiveChunkSmokeTest), ...
    'LiveChunkSmokeTest finalization failed.');
end

function out = local_buffer(command, arg, varargin) %#ok<INUSD>
switch char(command)
    case {'get_hdr','wait_dat'}
        out = struct('fsample', 2400, 'nsamples', 1000, 'nchans', 1, ...
            'channel_names', {{'MEG001'}});
    case 'get_dat'
        out = struct('buf', zeros(1, arg(2) - arg(1) + 1));
    otherwise
        error('Unsupported test command.');
end
end
