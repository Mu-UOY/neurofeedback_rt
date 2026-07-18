function WaitResult = nf_wait_for_manual_start(RTConfig, phase)
% NF_WAIT_FOR_MANUAL_START Wait for operator start before a live phase.
%
% USAGE:  WaitResult = nf_wait_for_manual_start(RTConfig, phase)
%
% DESCRIPTION:
%     Performs the live manual-start gate without touching Source. Tests can
%     opt into immediate auto-start only when a FieldTrip test hook is set.

%% ===== INITIALIZE RESULT =====
% Stable schema supports audit logging even when no wait occurs.
if nargin < 2 || isempty(phase)
    phase = '';
end
WaitResult = struct();
WaitResult.Type = 'manual_start';
WaitResult.Phase = char(phase);
WaitResult.Waited = false;
WaitResult.AutoStarted = false;
WaitResult.StartedAt = local_now_text();
WaitResult.EndedAt = WaitResult.StartedAt;
WaitResult.WaitDurationSeconds = 0;
WaitResult.Message = '';
WaitResult.HandledExternally = false;
WaitResult.MaxWaitSeconds = local_get_numeric(RTConfig, ...
    {'Protocol','ManualStartMaxWaitSeconds'}, Inf);
WaitResult.TimedOut = false;
WaitResult.StopReason = '';
WaitResult.TimingSource = nf_modes().TimingSource.None;

%% ===== HANDLE DISABLED MANUAL START =====
% Tests and noninteractive rehearsals can disable the gate explicitly.
if ~local_get_logical(RTConfig, {'Protocol','RequireManualStart'}, true)
    WaitResult.Message = 'Manual start disabled.';
    return;
end

%% ===== HANDLE TEST-HOOK AUTO START =====
% Auto-start is allowed only for explicit hardware-free test-hook configs.
hasTestHook = local_has_test_hook(RTConfig);
allowAuto = local_get_logical(RTConfig, {'Protocol','AllowAutoStartForTestHook'}, false);
isDevelopmentSession = local_get_logical(RTConfig, ...
    {'DevelopmentSession','Enabled'}, false);
if hasTestHook && allowAuto && ~isDevelopmentSession
    WaitResult.AutoStarted = true;
    WaitResult.Message = 'Manual start auto-started for test hook.';
    WaitResult.EndedAt = local_now_text();
    return;
end
if hasTestHook && allowAuto && ...
        nf_is_strict_step0_headless_contract(RTConfig)
    Modes = nf_modes();
    WaitResult.WaitDurationSeconds = local_test_wait_duration(RTConfig, phase, Modes);
    WaitResult.MaxWaitSeconds = local_get_numeric(RTConfig, ...
        {'Protocol','ManualStartMaxWaitSeconds'}, Inf);
    WaitResult.TimedOut = WaitResult.WaitDurationSeconds > WaitResult.MaxWaitSeconds;
    WaitResult.AutoStarted = true;
    WaitResult.TimingSource = Modes.TimingSource.TestHookLogical;
    if WaitResult.TimedOut
        WaitResult.StopReason = Modes.StopReason.TransitionTimeout;
        WaitResult.Message = 'Manual start exceeded the configured maximum wait.';
    else
        WaitResult.Message = 'Manual start auto-started using logical test timing.';
    end
    WaitResult.EndedAt = local_now_text();
    return;
end

%% ===== WAIT FOR INPUT =====
% Finite waits require nonblocking Psychtoolbox keyboard polling.
WaitResult.Waited = true;
prompt = local_get_text(RTConfig, {'Protocol','ManualStartPrompt'}, ...
    'Press any key to start the live phase.');
tStart = tic;
WaitResult.TimingSource = nf_modes().TimingSource.Monotonic;
try
    if isfinite(WaitResult.MaxWaitSeconds)
        if exist('KbCheck', 'file') == 0 && exist('KbCheck', 'builtin') == 0
            error('Bounded manual start requires Psychtoolbox KbCheck.');
        end
        while true
            [keyIsDown] = KbCheck();
            elapsed = toc(tStart);
            if keyIsDown || elapsed > WaitResult.MaxWaitSeconds
                break;
            end
            pause(RTConfig.Protocol.ManualStartPollSeconds);
        end
        WaitResult.TimedOut = elapsed > WaitResult.MaxWaitSeconds;
    elseif exist('KbWait', 'file') ~= 0 || exist('KbWait', 'builtin') ~= 0
        KbWait();
    elseif exist('KbCheck', 'file') ~= 0 || exist('KbCheck', 'builtin') ~= 0
        while true
            [keyIsDown] = KbCheck();
            if keyIsDown
                break;
            end
            pause(RTConfig.Protocol.ManualStartPollSeconds);
        end
    else
        input([prompt ' '], 's');
    end
catch ME
    error('Manual start failed: %s', ME.message);
end

WaitResult.EndedAt = local_now_text();
WaitResult.WaitDurationSeconds = toc(tStart);
if WaitResult.TimedOut
    WaitResult.StopReason = nf_modes().StopReason.TransitionTimeout;
    WaitResult.Message = 'Manual start exceeded the configured maximum wait.';
else
    WaitResult.Message = 'Manual start completed.';
end

end

function duration = local_test_wait_duration(RTConfig, phase, Modes)
% Dispatch logical timing exclusively from the explicit phase argument.
switch char(phase)
    case Modes.Session.LiveResting
        fieldName = 'Resting';
    case Modes.Phase.Transition
        fieldName = 'Transition';
    case Modes.Session.LiveTrial
        fieldName = 'Trial';
    otherwise
        error('Unknown Step 0 manual-start phase: %s', char(phase));
end
duration = local_get_numeric(RTConfig, ...
    {'DevelopmentSession','TestHooks','ManualStartWaitDurationSeconds',fieldName}, 0);
end

function tf = local_has_test_hook(RTConfig)
% Detect explicit FieldTrip test hook.
tf = isfield(RTConfig, 'Source') && isfield(RTConfig.Source, 'FieldTrip') && ...
    isfield(RTConfig.Source.FieldTrip, 'TestBufferFcn') && ...
    ~isempty(RTConfig.Source.FieldTrip.TestBufferFcn);
end

function value = local_get_logical(S, path, defaultValue)
% Read optional nested logical-like scalar.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if islogical(cursor) && isscalar(cursor)
    value = cursor;
elseif isnumeric(cursor) && isscalar(cursor) && isfinite(cursor)
    value = cursor ~= 0;
end
end

function value = local_get_text(S, path, defaultValue)
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

function value = local_get_numeric(S, path, defaultValue)
% Read optional nested numeric scalar.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if isnumeric(cursor) && isscalar(cursor) && ~isnan(cursor)
    value = double(cursor);
end
end

function value = local_now_text()
% Return a stable timestamp string.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
else
    value = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
end
