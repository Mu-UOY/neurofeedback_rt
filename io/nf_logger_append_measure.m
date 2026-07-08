function Logger = nf_logger_append_measure(Logger, Measure)
% NF_LOGGER_APPEND_MEASURE Append a normalized Measure record.
%
% USAGE:  Logger = nf_logger_append_measure(Logger, Measure)

%% ===== CHECK INPUT =====
% Empty measures are skipped but recorded in Logger.Messages.
if isempty(Measure)
    Logger.Messages{end + 1} = 'Empty Measure input was not appended.';
    return;
end
if ~isstruct(Logger)
    error('Logger must be a struct.');
end
if ~isstruct(Measure)
    error('Measure must be a struct or empty.');
end

%% ===== NORMALIZE AND APPEND =====
% Missing fields get canonical defaults; existing NaN runtime values stay NaN.
record = local_normalize_measure(Measure);
Logger.NMeasures = Logger.NMeasures + 1;
if isempty(Logger.Measures)
    Logger.Measures = record;
else
    Logger.Measures(end + 1) = record;
end

end

function record = local_normalize_measure(Measure)
% Convert older partial Measure structs into the canonical schema.
record = nf_measure_empty();
fields = fieldnames(record);
for iField = 1:numel(fields)
    fieldName = fields{iField};
    if isfield(Measure, fieldName)
        record.(fieldName) = Measure.(fieldName);
    end
end
end
