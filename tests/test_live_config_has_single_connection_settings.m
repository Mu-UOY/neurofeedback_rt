function test_live_config_has_single_connection_settings()
% TEST_LIVE_CONFIG_HAS_SINGLE_CONNECTION_SETTINGS Check Step 3A config fields.

%% ===== CHECK LIVE FIELDTRIP SETTINGS =====
% Editable live settings and origin labels must be centralized in RTConfig.
RTConfig = nf_live_config();
FT = RTConfig.Source.FieldTrip;

assert(isfield(RTConfig.Source, 'Benjamin'), 'Missing Source.Benjamin config.');
assert(isfield(RTConfig.Source.Benjamin, 'CodeRoot'), 'Missing Benjamin.CodeRoot.');
assert(isfield(RTConfig.Source.Benjamin, 'WiringNotes'), 'Missing Benjamin.WiringNotes.');
assert(isfield(RTConfig.Source.Benjamin, 'WiringEvidenceFiles'), ...
    'Missing Benjamin.WiringEvidenceFiles.');

requiredFT = {'Host','Port','TimeoutMs','BufferMPath','FieldTripRoot', ...
    'RequiredBufferRoot','AllowAlreadyOnPathBuffer','AllowMatlabToolboxBuffer', ...
    'UseBrainstormPluginPaths','UseCTFRes4FromHeader','RequireCTFRes4', ...
    'TestBufferFcn','SettingOrigin'};
for iField = 1:numel(requiredFT)
    assert(isfield(FT, requiredFT{iField}), ...
        'Missing Source.FieldTrip.%s.', requiredFT{iField});
end

requiredOrigins = {'Host','Port','BufferMPath','FieldTripRoot', ...
    'RequiredBufferRoot','UseBrainstormPluginPaths'};
for iField = 1:numel(requiredOrigins)
    assert(isfield(FT.SettingOrigin, requiredOrigins{iField}), ...
        'Missing SettingOrigin.%s.', requiredOrigins{iField});
end

assert(~isfield(RTConfig.Source, 'Provenance'), ...
    'Source.Provenance should not mix runtime values and origin labels.');

end
