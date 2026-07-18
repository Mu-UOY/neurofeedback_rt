function Safety = nf_safety_init_stop_flag(RTConfig, phase)
% NF_SAFETY_INIT_STOP_FLAG Initialize a simple runtime stop flag.
%
% USAGE:  Safety = nf_safety_init_stop_flag(RTConfig, phase)
%
% DESCRIPTION:
%     Creates the minimal safety state used by acquisition-only live smoke
%     tests. This helper does not open displays or require Psychtoolbox.

%% ===== CHECK INPUTS =====
% Step 3B supports the explicit phase-based signature only.
if nargin < 2 || isempty(phase)
    error('nf_safety_init_stop_flag requires RTConfig and phase.');
end

%% ===== INITIALIZE SAFETY STATE =====
% Keep fields stable so tests and later live runners can audit stop reasons.
Safety = struct();
Safety.Phase = char(phase);
Safety.StartTime = local_now_text();
Safety.StartTic = tic;
Safety.MaxDurationSeconds = local_max_duration(RTConfig, Safety.Phase);
Safety.UseMaxDurationFailsafe = local_get_logical(RTConfig, {'Safety','UseMaxDurationFailsafe'}, true);
Safety.EnableKeyboardStop = local_get_logical(RTConfig, {'Safety','EnableKeyboardStop'}, true);
Safety.StopKey = local_get_text(RTConfig, {'Safety','StopKey'}, 'ESCAPE');
Safety.SecondaryStopKey = local_get_text(RTConfig, {'Safety','SecondaryStopKey'}, 'q');
Safety.EnableStopFile = local_get_logical(RTConfig, {'Safety','EnableStopFile'}, false);
Safety.StopFilePath = local_get_text(RTConfig, {'Safety','StopFilePath'}, '');
Safety.StopRequested = false;
Safety.StopReason = '';

end

function value = local_max_duration(RTConfig, phase)
% Resolve the phase-specific duration without adding another source of truth.
switch char(phase)
    case 'live_chunk_smoke_test'
        value = local_first_numeric(RTConfig, { ...
            {'LiveChunkSmokeTest','DurationSeconds'}, ...
            {'LiveDryRun','DurationSeconds'}});

    case {'live_rt_dry_run','trial_like_dry_run'}
        value = local_first_numeric(RTConfig, { ...
            {'LiveRTDryRun','DurationSeconds'}, ...
            {'LiveDryRun','DurationSeconds'}});

    case 'resting'
        value = local_first_numeric(RTConfig, {{'Protocol','DurationSeconds','Resting'}});

    case {'trial','live_trial'}
        value = local_first_numeric(RTConfig, {{'Protocol','Trial','MaxFailsafeSeconds'}});

    case 'live_resting'
        value = local_first_numeric(RTConfig, {{'Protocol','DurationSeconds','Resting'}});

    otherwise
        value = Inf;
end
end

function value = local_first_numeric(S, paths)
% Return the first finite numeric scalar at one of the requested paths.
value = Inf;
for iPath = 1:numel(paths)
    candidate = local_get_numeric(S, paths{iPath}, []);
    if ~isempty(candidate)
        value = candidate;
        return;
    end
end
end

function value = local_get_numeric(S, path, defaultValue)
% Read optional nested finite numeric scalar field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
if isnumeric(cursor) && isscalar(cursor) && isfinite(cursor)
    value = double(cursor);
end
end

function value = local_get_logical(S, path, defaultValue)
% Read optional nested logical field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
if islogical(cursor) && isscalar(cursor)
    value = cursor;
end
end

function value = local_get_text(S, path, defaultValue)
% Read optional nested text field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
if ischar(cursor) || (isstring(cursor) && isscalar(cursor))
    value = char(cursor);
end
end

function value = local_now_text()
% Return a stable timestamp string when datetime is available.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
else
    value = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
end
