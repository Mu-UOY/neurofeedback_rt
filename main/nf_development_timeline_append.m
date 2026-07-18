function Timeline = nf_development_timeline_append(Timeline, eventType, phase, ...
    sampleStart, sampleEnd, message, isError)
% NF_DEVELOPMENT_TIMELINE_APPEND Append one event and atomically rewrite HTML.

Event = struct();
Event.Sequence = numel(Timeline.Events) + 1;
Event.EventType = char(eventType);
Event.Phase = char(phase);
Event.TimestampText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Event.ElapsedSeconds = toc(Timeline.StartedTic);
Event.SampleStart = sampleStart;
Event.SampleEnd = sampleEnd;
Event.Message = char(message);
Event.IsError = logical(isError);
if isempty(Timeline.Events)
    Timeline.Events = Event;
else
    Timeline.Events(end + 1) = Event;
end
local_write_html(Timeline);

end

function local_write_html(Timeline)
% Write a complete temporary document, then replace the final file.
tempPath = [Timeline.Path Timeline.TempSuffix];
fid = fopen(tempPath, 'w');
if fid < 0
    error('Could not open Step 0 timeline temporary file.');
end
cleanup = onCleanup(@() local_close_if_open(fid)); %#ok<NASGU>
fprintf(fid, '<!doctype html><html><head><meta charset="utf-8"><title>Step 0 timeline</title>');
fprintf(fid, '<style>body{font-family:Arial,sans-serif}table{border-collapse:collapse}');
fprintf(fid, 'th,td{border:1px solid #bbb;padding:4px 7px}.error{background:#fee}</style>');
fprintf(fid, '</head><body><h1>Development session timeline: %s</h1><table>', ...
    local_escape(local_timeline_run_id(Timeline)));
fprintf(fid, '<tr><th>#</th><th>Event</th><th>Phase</th><th>Time</th>');
fprintf(fid, '<th>Elapsed (s)</th><th>Samples</th><th>Message</th></tr>');
for iEvent = 1:numel(Timeline.Events)
    E = Timeline.Events(iEvent);
    rowClass = '';
    if E.IsError
        rowClass = ' class="error"';
    end
    fprintf(fid, '<tr%s><td>%d</td><td>%s</td><td>%s</td><td>%s</td>', ...
        rowClass, E.Sequence, local_escape(E.EventType), local_escape(E.Phase), ...
        local_escape(E.TimestampText));
    fprintf(fid, '<td>%.6f</td><td>%s</td><td>%s</td></tr>', E.ElapsedSeconds, ...
        local_sample_text(E.SampleStart, E.SampleEnd), local_escape(E.Message));
end
fprintf(fid, '</table></body></html>');
fclose(fid);
fid = -1; %#ok<NASGU>
[ok, msg] = movefile(tempPath, Timeline.Path, 'f');
if ~ok
    error('Could not replace Step 0 timeline: %s', msg);
end
end

function value = local_timeline_run_id(Timeline)
value = '';
if isstruct(Timeline) && isfield(Timeline, 'RunID') && ...
        (ischar(Timeline.RunID) || isstring(Timeline.RunID))
    value = char(Timeline.RunID);
end
end

function textValue = local_sample_text(firstSample, lastSample)
if isfinite(firstSample) && isfinite(lastSample)
    textValue = sprintf('%g:%g', firstSample, lastSample);
else
    textValue = '';
end
end

function value = local_escape(value)
% Escape all characters that can alter HTML text nodes.
value = char(value);
value = strrep(value, '&', '&amp;');
value = strrep(value, '<', '&lt;');
value = strrep(value, '>', '&gt;');
value = strrep(value, '"', '&quot;');
value = strrep(value, '''', '&#39;');
end

function local_close_if_open(fid)
if fid > 0
    try
        fclose(fid);
    catch
    end
end
end
