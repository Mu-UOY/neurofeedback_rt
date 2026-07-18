function [successMet, TrialState] = nf_trial_success_criterion_met(Measure, TrialState, RTConfig)
% NF_TRIAL_SUCCESS_CRITERION_MET Update live trial success state.
%
% USAGE:  [successMet, TrialState] = nf_trial_success_criterion_met(Measure, TrialState, RTConfig)

%% ===== INITIALIZE STATE =====
% Stable fields make success behavior auditable.
if nargin < 2 || isempty(TrialState) || ~isstruct(TrialState)
    TrialState = struct();
end
TrialState = local_init_trial_state(TrialState);
successMet = false;

%% ===== HANDLE DISABLED SUCCESS =====
% Success is opt-in; manual stop remains the default endpoint.
if ~local_get_nested_logical(RTConfig, {'Protocol','Trial','Success','Enabled'}, false)
    TrialState.SuccessMet = false;
    return;
end

%% ===== READ SOURCE VALUE =====
sourceField = local_get_nested_text(RTConfig, {'Protocol','Trial','Success','SourceField'}, 'ZSmoothed');
TrialState.LastSuccessField = sourceField;
TrialState.LastSuccessValue = NaN;

if isempty(Measure) || ~isstruct(Measure) || ~isfield(Measure, 'IsValid') || ...
        ~Measure.IsValid || ~isfield(Measure, sourceField) || ...
        ~isfinite(Measure.(sourceField))
    TrialState.SuccessConsecutiveCount = 0;
    TrialState.SuccessMet = false;
    return;
end

value = Measure.(sourceField);
threshold = local_get_nested_numeric(RTConfig, {'Protocol','Trial','Success','Threshold'}, 1);
TrialState.LastSuccessValue = value;

%% ===== UPDATE CONSECUTIVE COUNT =====
% Only finite valid source values can advance success.
if value >= threshold
    TrialState.SuccessConsecutiveCount = TrialState.SuccessConsecutiveCount + 1;
else
    TrialState.SuccessConsecutiveCount = 0;
end

required = local_get_nested_numeric(RTConfig, ...
    {'Protocol','Trial','Success','RequiredConsecutiveValidUpdates'}, 20);
successMet = TrialState.SuccessConsecutiveCount >= required;
TrialState.SuccessMet = successMet;

end

function TrialState = local_init_trial_state(TrialState)
% Fill missing canonical fields.
TrialState = local_set_missing(TrialState, 'SuccessConsecutiveCount', 0);
TrialState = local_set_missing(TrialState, 'SuccessMet', false);
TrialState = local_set_missing(TrialState, 'NFeedbackUpdates', 0);
TrialState = local_set_missing(TrialState, 'NValidMeasures', 0);
TrialState = local_set_missing(TrialState, 'StartedAt', local_now_text());
TrialState = local_set_missing(TrialState, 'LastSuccessValue', NaN);
TrialState = local_set_missing(TrialState, 'LastSuccessField', '');
end

function S = local_set_missing(S, fieldName, value)
% Set one field when absent or empty.
if ~isfield(S, fieldName) || isempty(S.(fieldName))
    S.(fieldName) = value;
end
end

function value = local_get_nested_logical(S, path, defaultValue)
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

function value = local_get_nested_numeric(S, path, defaultValue)
% Read optional nested numeric scalar.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
if isnumeric(cursor) && isscalar(cursor) && isfinite(cursor)
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
