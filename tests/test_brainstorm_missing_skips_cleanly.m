function test_brainstorm_missing_skips_cleanly()
% TEST_BRAINSTORM_MISSING_SKIPS_CLEANLY Ensure optional Brainstorm skip works.

%% ===== BUILD SYNTHETIC DATA =====
% Brainstorm-specific data are intentionally not provided.
rng(12);
Fs = 1200;
t = 0:(1 / Fs):(4 - 1 / Fs);
Data = struct();
Data.X = sin(2 * pi * 6 * t) + 0.05 * randn(size(t));
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001'};
Data.Events = [];
Data.Metadata = struct();

%% ===== CONFIGURE BRAINSTORM SKIP MODE =====
% Missing Brainstorm must not crash first-version validation.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Spatial.NChannels = 1;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Validation.Step1.Brainstorm.Mode = 'skip';
RTConfig.Validation.Step1.Brainstorm.RequireForPass = false;

Ref = nf_make_offline_reference(Data, RTConfig);
Results = nf_validate_iir_sos_comparison(Data, Ref, RTConfig);

%% ===== ASSERT CLEAN SKIP =====
% IIRRef should still be produced for inspection.
assert(strcmp(Results.Status, 'SKIPPED'), 'Brainstorm skip mode did not return SKIPPED.');
assert(isfield(Results, 'IIRRef'), 'Skipped comparison did not retain IIRRef.');
assert(~isempty(Results.Message), 'Skipped comparison should include a useful message.');

RTConfig.Validation.Step1.Brainstorm.Mode = 'bst_function';
Results = nf_validate_iir_sos_comparison(Data, Ref, RTConfig);

assert(strcmp(Results.Status, 'SKIPPED'), 'Unwired bst_function mode did not return SKIPPED.');
assert(~isempty(Results.Message), 'Unwired bst_function skip should include a useful message.');

RTConfig.Validation.Step1.Brainstorm.RequireForPass = true;
didError = false;
try
    nf_validate_iir_sos_comparison(Data, Ref, RTConfig);
catch ME
    didError = ~isempty(strfind(ME.message, 'signature has not been manually verified')); %#ok<STREMP>
end
assert(didError, 'Unwired bst_function mode did not error when RequireForPass was true.');

end
