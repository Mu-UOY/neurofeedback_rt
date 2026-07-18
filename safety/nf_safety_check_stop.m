function [stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig)
% NF_SAFETY_CHECK_STOP Check manual stop state without requiring PTB.
%
% USAGE:  [stopRequested, Safety] = nf_safety_check_stop(Safety, RTConfig)

%% ===== DEFENSIVE DEFAULTS =====
% Headless tests should never fail because safety state is incomplete.
if nargin < 1 || isempty(Safety) || ~isstruct(Safety)
    Safety = struct();
end
if ~isfield(Safety, 'StopRequested')
    Safety.StopRequested = false;
end
if ~isfield(Safety, 'StopReason')
    Safety.StopReason = '';
end

%% ===== RETURN EXISTING STOP =====
% Once a stop is requested, keep reporting it.
if Safety.StopRequested
    stopRequested = true;
    return;
end

%% ===== CHECK STOP FILE =====
% Stop-file control is optional but must be real when enabled.
enableStopFile = local_field(Safety, 'EnableStopFile', false);
stopFilePath = local_field(Safety, 'StopFilePath', '');
if enableStopFile && ~isempty(stopFilePath) && exist(char(stopFilePath), 'file') == 2
    Modes = nf_modes();
    Safety.StopRequested = true;
    Safety.StopReason = Modes.StopReason.StopFile;
    stopRequested = true;
    return;
end

%% ===== CHECK KEYBOARD STOP =====
% KbCheck/KbName may not exist in automated or headless environments.
enableKeyboard = local_field(Safety, 'EnableKeyboardStop', true);
if enableKeyboard && exist('KbCheck', 'file') ~= 0
    try
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown && local_matches_stop_key(keyCode, Safety)
            Safety.StopRequested = true;
            Safety.StopReason = 'manual';
        end
    catch
        % Keyboard polling is optional for headless tests; fail safely.
    end
end

stopRequested = Safety.StopRequested;

end

function tf = local_matches_stop_key(keyCode, Safety)
% Detect ESCAPE or q using KbName when available.
tf = false;
if exist('KbName', 'file') == 0
    return;
end
try
    stopKey = KbName(local_field(Safety, 'StopKey', 'ESCAPE'));
    secondaryKey = KbName(local_field(Safety, 'SecondaryStopKey', 'q'));
    keyIdx = find(keyCode);
    tf = any(ismember(keyIdx, [stopKey secondaryKey]));
catch
    tf = false;
end
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
