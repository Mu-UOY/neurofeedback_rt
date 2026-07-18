function Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState)
% NF_DETERMINE_STOP_REASON Apply live-loop stop priority.
%
% USAGE:  Stop = nf_determine_stop_reason(Safety, TrialState, RTConfig, LoopState)

%% ===== INITIALIZE OUTPUT =====
% Fail closed only when loop state indicates a stop condition.
Modes = nf_modes();
Stop = struct();
Stop.Reason = Modes.StopReason.CompletedUnknown;
Stop.ShouldStop = false;
Stop.Message = '';

%% ===== PRIORITY 1: ERROR =====
if local_get_logical(LoopState, 'ErrorOccurred', false)
    Stop.Reason = Modes.StopReason.Error;
    Stop.ShouldStop = true;
    Stop.Message = local_get_text(LoopState, 'LastError', 'Live loop error.');
    return;
end

%% ===== PRIORITY 2: HARD FAILSAFE =====
if local_get_logical(LoopState, 'HardFailsafeExceeded', false) || ...
        nf_safety_hard_failsafe_exceeded(Safety)
    Stop.Reason = Modes.StopReason.HardFailsafe;
    Stop.ShouldStop = true;
    Stop.Message = 'Hard failsafe exceeded.';
    return;
end

%% ===== PRIORITY 3: TIMEOUT =====
if local_get_logical(LoopState, 'TimeoutLimitExceeded', false)
    Stop.Reason = Modes.StopReason.Timeout;
    Stop.ShouldStop = true;
    Stop.Message = 'Timeout limit exceeded.';
    return;
end

%% ===== PRIORITY 4: MANUAL =====
if local_get_logical(LoopState, 'ManualStopRequested', false) || ...
        local_get_logical(Safety, 'StopRequested', false)
    safetyReason = local_get_text(Safety, 'StopReason', '');
    if strcmp(safetyReason, Modes.StopReason.StopFile)
        Stop.Reason = Modes.StopReason.StopFile;
        Stop.Message = 'Stop file requested.';
    else
        Stop.Reason = Modes.StopReason.Manual;
        Stop.Message = 'Manual stop requested.';
    end
    Stop.ShouldStop = true;
    return;
end

%% ===== PRIORITY 5: SUCCESS =====
stopRule = local_get_nested_text(RTConfig, {'Protocol','Trial','StopRule'}, '');
if strcmp(stopRule, Modes.TrialStop.ManualOrSuccess) && ...
        local_get_logical(TrialState, 'SuccessMet', false)
    Stop.Reason = Modes.StopReason.Success;
    Stop.ShouldStop = true;
    Stop.Message = 'Trial success criterion met.';
    return;
end

%% ===== PRIORITY 6: FIXED DURATION =====
if strcmp(stopRule, Modes.TrialStop.FixedDuration) && ...
        local_get_logical(LoopState, 'FixedDurationCompleted', false)
    Stop.Reason = 'fixed_duration';
    Stop.ShouldStop = true;
    Stop.Message = 'Fixed duration completed.';
    return;
end

%% ===== PRIORITY 7: NO STOP =====
Stop.Reason = Modes.StopReason.CompletedUnknown;
Stop.ShouldStop = false;
Stop.Message = '';

end

function value = local_get_logical(S, fieldName, defaultValue)
% Read optional logical-like field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    raw = S.(fieldName);
    if islogical(raw) && isscalar(raw)
        value = raw;
    elseif isnumeric(raw) && isscalar(raw) && isfinite(raw)
        value = raw ~= 0;
    end
end
end

function value = local_get_text(S, fieldName, defaultValue)
% Read optional text field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName)) && ...
        (ischar(S.(fieldName)) || isstring(S.(fieldName)))
    value = char(S.(fieldName));
end
end

function value = local_get_nested_text(S, path, defaultValue)
% Read optional nested text.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if ischar(cursor) || isstring(cursor)
    value = char(cursor);
end
end
