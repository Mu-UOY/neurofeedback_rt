function tf = nf_safety_hard_failsafe_exceeded(Safety)
% NF_SAFETY_HARD_FAILSAFE_EXCEEDED True if runtime exceeded max duration.
%
% USAGE:  tf = nf_safety_hard_failsafe_exceeded(Safety)

%% ===== CHECK SAFETY STATE =====
% Incomplete safety state should not crash acquisition-only tests.
tf = false;
if nargin < 1 || isempty(Safety) || ~isstruct(Safety) || ...
        ~isfield(Safety, 'MaxDurationSeconds') || isempty(Safety.MaxDurationSeconds)
    return;
end
if isfield(Safety, 'UseMaxDurationFailsafe') && ~isempty(Safety.UseMaxDurationFailsafe) && ...
        ~logical(Safety.UseMaxDurationFailsafe)
    return;
end
if ~isnumeric(Safety.MaxDurationSeconds) || ~isscalar(Safety.MaxDurationSeconds) || ...
        isinf(Safety.MaxDurationSeconds)
    return;
end

%% ===== CHECK ELAPSED TIME =====
% Prefer tic/toc state; fall back safely if unavailable.
elapsed = NaN;
if isfield(Safety, 'StartTic') && ~isempty(Safety.StartTic)
    try
        elapsed = toc(Safety.StartTic);
    catch
        elapsed = NaN;
    end
end
if isfinite(elapsed)
    tf = elapsed > Safety.MaxDurationSeconds;
end

end
