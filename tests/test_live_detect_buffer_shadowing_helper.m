function test_live_detect_buffer_shadowing_helper()
% TEST_LIVE_DETECT_BUFFER_SHADOWING_HELPER Check direct shadowing logic.

%% ===== NO CANDIDATES FAILS =====
RTConfig = nf_live_config();
S = nf_live_detect_buffer_shadowing({}, '', RTConfig);
assert(S.Pass == false, 'Missing buffer candidates passed.');
assert(S.BufferFound == false, 'Missing buffer candidates marked found.');

%% ===== MATLAB TOOLBOX BUFFER FAILS UNLESS ALLOWED =====
toolboxBuffer = fullfile('C:', 'MATLAB', 'toolbox', 'signal', 'signal', 'buffer.m');
S = nf_live_detect_buffer_shadowing({toolboxBuffer}, toolboxBuffer, RTConfig);
assert(S.Pass == false, 'MATLAB toolbox buffer passed by default.');
assert(S.BufferLooksLikeMatlabToolbox == true, 'Toolbox buffer heuristic did not match.');

RTConfig.Source.FieldTrip.AllowMatlabToolboxBuffer = true;
S = nf_live_detect_buffer_shadowing({toolboxBuffer}, toolboxBuffer, RTConfig);
assert(S.Pass == true, 'Explicit toolbox allowance did not pass.');

%% ===== REQUIRED ROOT MISMATCH IS DISTINCT =====
RTConfig = nf_live_config();
RTConfig.Source.FieldTrip.RequiredBufferRoot = fullfile('C:', 'required');
selected = fullfile('C:', 'fieldtrip', 'realtime', 'buffer', 'matlab', 'buffer.m');
S = nf_live_detect_buffer_shadowing({selected}, selected, RTConfig);
assert(S.Pass == false, 'RequiredBufferRoot mismatch passed.');
assert(S.BufferLooksLikeMatlabToolbox == false, 'Required-root mismatch was mislabeled toolbox shadowing.');
assert(contains(strjoin(S.Messages, ' '), 'RequiredBufferRoot'), ...
    'Required-root mismatch message missing.');

%% ===== VALID FIELDTRIP-LIKE PATH PASSES =====
RTConfig.Source.FieldTrip.RequiredBufferRoot = fullfile('C:', 'fieldtrip');
S = nf_live_detect_buffer_shadowing({selected}, selected, RTConfig);
assert(S.Pass == true, 'Valid required-root buffer path failed.');

end
