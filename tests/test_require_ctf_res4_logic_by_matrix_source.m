function test_require_ctf_res4_logic_by_matrix_source()
% TEST_REQUIRE_CTF_RES4_LOGIC_BY_MATRIX_SOURCE Check CTF metadata rules.

%% ===== ACQUISITION-ONLY PRECOMPUTED DOES NOT FORCE CTF =====
% Acquisition-only sessions may inspect chunks before spatial config exists.
Modes = nf_modes();
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Session.Mode = Modes.Session.LiveDiagnostics;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = '';
RTConfig.Source.CTF.ApplyChannelGains = true;
RTConfig.Source.CTF.ApplyMegRefCorrection = true;
RTConfig.Source.FieldTrip.RequireCTFRes4 = [];
RTConfig = nf_finalize_config(RTConfig);
assert(RTConfig.Source.FieldTrip.RequireCTFRes4 == false, ...
    'Acquisition-only Precomputed mode forced CTF res4.');

%% ===== SPATIAL PRECOMPUTED REQUIRES CTF =====
% This dummy file proves only that the path exists.
% Step 3A-0a does not validate precomputed matrix contents or loading.
tmpPath = [tempname, '.mat'];
dummy = 1;
save(tmpPath, 'dummy');
cleanupObj = onCleanup(@() delete(tmpPath));

RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Session.Mode = Modes.Session.LiveSelfTest;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.Precomputed;
RTConfig.Spatial.CombinedMatrixPath = tmpPath;
RTConfig.Source.FieldTrip.RequireCTFRes4 = [];
RTConfig = nf_finalize_config(RTConfig);
assert(RTConfig.Source.FieldTrip.RequireCTFRes4 == true, ...
    'Spatial Precomputed mode did not require CTF res4.');

%% ===== TECHNICAL FALLBACK WITHOUT CTF CORRECTIONS DOES NOT REQUIRE CTF =====
% Technical fallback is a config selection, not a matrix builder in this step.
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Session.Mode = Modes.Session.LiveSelfTest;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.FieldTrip.RequireCTFRes4 = [];
RTConfig = nf_finalize_config(RTConfig);
assert(RTConfig.Source.FieldTrip.RequireCTFRes4 == false, ...
    'Technical fallback without CTF corrections required CTF res4.');

%% ===== TECHNICAL FALLBACK WITH CTF FLAGS CANNOT DISABLE CTF =====
% Explicitly disabling CTF metadata while requesting CTF corrections is invalid.
RTConfig = nf_live_config();
RTConfig.Debug.Verbose = false;
RTConfig.Session.Mode = Modes.Session.LiveSelfTest;
RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;
RTConfig.Source.CTF.ApplyChannelGains = true;
RTConfig.Source.CTF.ApplyMegRefCorrection = true;
RTConfig.Source.CTF.ApplyProjector = false;
RTConfig.Source.FieldTrip.RequireCTFRes4 = false;

didError = false;
try
    nf_finalize_config(RTConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'Technical fallback without CTF res4'), ...
        'Unexpected technical-fallback CTF error: %s', ME.message);
end
assert(didError, 'Technical fallback accepted CTF corrections without CTF res4.');

clear cleanupObj

end
