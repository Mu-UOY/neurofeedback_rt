function nf_safety_shutdown(Safety)
% NF_SAFETY_SHUTDOWN No-op safety cleanup for acquisition-only tests.
%
% USAGE:  nf_safety_shutdown(Safety)

%% ===== NO-OP CLEANUP =====
% Step 3B safety does not own displays, sockets, or Psychtoolbox state.
if nargin < 1
    return;
end

end
