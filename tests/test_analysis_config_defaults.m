function test_analysis_config_defaults()
% TEST_ANALYSIS_CONFIG_DEFAULTS Check Step 2C config fields.

%% ===== CHECK DEFAULT CONFIG =====
% Analysis defaults are noninteractive; metadata fields may stay empty.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig = nf_check_config(RTConfig);

assert(isfield(RTConfig, 'Analysis'), 'RTConfig.Analysis is missing.');
assert(strcmp(RTConfig.Analysis.DisplayMode, 'off'), ...
    'Analysis.DisplayMode must default to off.');
assert(strcmp(RTConfig.Analysis.ReportRoot, fullfile('outputs', 'reports')), ...
    'Analysis.ReportRoot default is incorrect.');
assert(islogical(RTConfig.Analysis.SaveFigures) && RTConfig.Analysis.SaveFigures, ...
    'Analysis.SaveFigures default is incorrect.');
assert(islogical(RTConfig.Analysis.SaveTables) && RTConfig.Analysis.SaveTables, ...
    'Analysis.SaveTables default is incorrect.');
assert(islogical(RTConfig.Analysis.SaveMat) && RTConfig.Analysis.SaveMat, ...
    'Analysis.SaveMat default is incorrect.');
assert(islogical(RTConfig.Analysis.FastMode) && ~RTConfig.Analysis.FastMode, ...
    'Analysis.FastMode default is incorrect.');
assert(RTConfig.Analysis.MinThetaOnMinusOffZ == 0.5, ...
    'Analysis.MinThetaOnMinusOffZ default is incorrect.');
assert(RTConfig.Analysis.MaxWrongBandMeanZ == 1.0, ...
    'Analysis.MaxWrongBandMeanZ default is incorrect.');

%% ===== CHECK SESSION METADATA DEFAULTS =====
% Metadata fields exist but are not required to be nonempty.
assert(isfield(RTConfig, 'SessionMetadata'), 'RTConfig.SessionMetadata is missing.');
metadataFields = {'RunID','DatasetName','SubjectID','SessionID','TrialID', ...
    'StrategyLabel','ConditionLabel'};
for iField = 1:numel(metadataFields)
    fieldName = metadataFields{iField};
    assert(isfield(RTConfig.SessionMetadata, fieldName), ...
        'SessionMetadata.%s is missing.', fieldName);
    assert(isempty(RTConfig.SessionMetadata.(fieldName)), ...
        'SessionMetadata.%s should default to empty.', fieldName);
end

%% ===== CHECK DEFENSIVE FILL =====
% Older configs without these sections should be filled by nf_check_config.
legacyConfig = nf_default_config();
legacyConfig = rmfield(legacyConfig, 'Analysis');
legacyConfig = rmfield(legacyConfig, 'SessionMetadata');
legacyConfig.Debug.Verbose = false;
legacyConfig = nf_check_config(legacyConfig);
assert(isfield(legacyConfig, 'Analysis'), 'nf_check_config did not fill Analysis.');
assert(isfield(legacyConfig, 'SessionMetadata'), ...
    'nf_check_config did not fill SessionMetadata.');
assert(strcmp(legacyConfig.Analysis.DisplayMode, 'off'), ...
    'Filled Analysis.DisplayMode should be off.');

%% ===== CHECK DISPLAY MODE VALIDATION =====
% Only explicitly supported display modes are accepted.
badConfig = nf_default_config();
badConfig.Debug.Verbose = false;
badConfig.Analysis.DisplayMode = 'figure';
didError = false;
try
    nf_check_config(badConfig);
catch ME
    didError = true;
    assert(contains(ME.message, 'Analysis.DisplayMode'), ...
        'Unexpected invalid display-mode error: %s', ME.message);
end
assert(didError, 'Invalid Analysis.DisplayMode was accepted.');

end
