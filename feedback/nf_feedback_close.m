function Feedback = nf_feedback_close(Feedback)
% NF_FEEDBACK_CLOSE Close feedback display resources safely.
%
% USAGE:  Feedback = nf_feedback_close(Feedback)

%% ===== HANDLE EMPTY INPUT =====
% Empty close calls are valid no-ops.
if isempty(Feedback)
    return;
end
if ~isstruct(Feedback)
    return;
end

%% ===== CLOSE DEBUG PLOT =====
% MATLAB figure handles can be closed safely when still valid.
backend = local_get_backend(Feedback);
if strcmp(backend, 'debug_plot')
    try
        if isfield(Feedback, 'FigureHandle') && ~isempty(Feedback.FigureHandle) && ...
                isgraphics(Feedback.FigureHandle)
            close(Feedback.FigureHandle);
        end
    catch
    end
end

%% ===== CLOSE PSYCHTOOLBOX WINDOW =====
% Cleanup must tolerate stale or partially initialized PTB handles.
if strcmp(backend, 'psychtoolbox')
    try
        if isfield(Feedback, 'WindowPtr') && ~isempty(Feedback.WindowPtr)
            if isfield(Feedback, 'ScreenFcn') && isa(Feedback.ScreenFcn, 'function_handle')
                Feedback.ScreenFcn('Close', Feedback.WindowPtr);
            elseif exist('Screen', 'file') ~= 0 || exist('Screen', 'builtin') ~= 0
                Screen('Close', Feedback.WindowPtr);
            end
        end
    catch
    end
end

%% ===== RESTORE OPTIONAL DISPLAY STATE =====
% Later live code may add these fields; close tolerates their absence.
if isfield(Feedback, 'PriorityLevel')
    try
        Priority(0);
    catch
    end
end
if isfield(Feedback, 'CursorWasHidden') && Feedback.CursorWasHidden
    try
        ShowCursor;
    catch
    end
end

%% ===== NULL HANDLES AND MARK CLOSED =====
% Double-close should not rely on stale handle tolerance.
Feedback.IsOpen = false;
Feedback.FigureHandle = [];
Feedback.AxesHandle = [];
Feedback.WindowPtr = [];
Feedback.WindowRect = [];

if ~isfield(Feedback, 'Messages') || ~iscell(Feedback.Messages)
    Feedback.Messages = {};
end
Feedback.Messages{end + 1} = 'Feedback display closed.';

end

function backend = local_get_backend(Feedback)
% Read backend with a fallback for partial structs.
backend = '';
if isstruct(Feedback) && isfield(Feedback, 'Backend') && ~isempty(Feedback.Backend)
    backend = char(Feedback.Backend);
end
end
