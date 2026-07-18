function tf = nf_is_strict_step0_headless_contract(RTConfig)
% NF_IS_STRICT_STEP0_HEADLESS_CONTRACT Check the isolated Step 0 test contract.
%
% USAGE:  tf = nf_is_strict_step0_headless_contract(RTConfig)
%
% DESCRIPTION:
%     Returns false for missing or malformed input. Configuration validation
%     owns descriptive errors; runtime seam activation only needs to fail
%     closed.

tf = false;
if nargin < 1 || ~isstruct(RTConfig) || ~isscalar(RTConfig)
    return;
end

Modes = nf_modes();
enabled = local_nested(RTConfig, {'DevelopmentSession','Enabled'});
displayMode = local_nested(RTConfig, {'DevelopmentSession','DisplayMode'});
hooksEnabled = local_nested(RTConfig, ...
    {'DevelopmentSession','TestHooks','Enabled'});
testBuffer = local_nested(RTConfig, {'Source','FieldTrip','TestBufferFcn'});
streamRole = local_nested(RTConfig, {'Source','FieldTrip','StreamRole'});
screenFcn = local_nested(RTConfig, ...
    {'DevelopmentSession','TestHooks','ScreenFcn'});
timeFcn = local_nested(RTConfig, ...
    {'DevelopmentSession','TestHooks','TimeFcn'});
productionEquivalent = local_nested(RTConfig, ...
    {'Session','ProductionEquivalent'});

tf = local_is_logical_value(enabled, true) && ...
    local_text_equals(displayMode, ...
        Modes.DevelopmentDisplay.HeadlessPsychtoolboxTest) && ...
    local_is_logical_value(hooksEnabled, true) && ...
    isa(testBuffer, 'function_handle') && isscalar(testBuffer) && ...
    local_text_equals(streamRole, Modes.StreamRole.TestHook) && ...
    isa(screenFcn, 'function_handle') && isscalar(screenFcn) && ...
    isa(timeFcn, 'function_handle') && isscalar(timeFcn) && ...
    local_is_logical_value(productionEquivalent, false);

end

function value = local_nested(S, path)
% Return [] when any intermediate contract field is absent or malformed.
value = [];
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isscalar(cursor) || ...
            ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
value = cursor;
end

function tf = local_is_logical_value(value, expected)
tf = islogical(value) && isscalar(value) && value == expected;
end

function tf = local_text_equals(value, expected)
tf = (ischar(value) && isrow(value) || ...
    isstring(value) && isscalar(value)) && strcmp(char(value), expected);
end
