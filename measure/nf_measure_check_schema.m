function Measure = nf_measure_check_schema(Measure)
% NF_MEASURE_CHECK_SCHEMA Validate a Measure struct against the canonical schema.
%
% USAGE:  Measure = nf_measure_check_schema(Measure)
%
% DESCRIPTION:
%     Confirms that a Measure contains the canonical fields from
%     nf_measure_empty and that key logical, string, and numeric fields have
%     the expected types.

%% ===== CHECK REQUIRED FIELDS =====
% The empty Measure defines the required schema.
expected = nf_measure_empty();
requiredFields = fieldnames(expected);

for i = 1:numel(requiredFields)
    if ~isfield(Measure, requiredFields{i})
        error('Measure missing required field: %s', requiredFields{i});
    end
end

%% ===== CHECK LOGICAL FIELDS =====
% Quality and trigger flags must stay scalar logicals.
logicalFields = {'IsValid','DroppedChunkFlag','GapInWindowFlag','ArtifactFlag','TriggerSent'};
for i = 1:numel(logicalFields)
    value = Measure.(logicalFields{i});
    if ~islogical(value) || ~isscalar(value)
        error('Measure.%s must be a scalar logical.', logicalFields{i});
    end
end

%% ===== CHECK TEXT FIELDS =====
% String-like fields are accepted as either char or string.
if ~(ischar(Measure.InvalidReason) || isstring(Measure.InvalidReason))
    error('Measure.InvalidReason must be char or string.');
end
if ~(ischar(Measure.SourceMode) || isstring(Measure.SourceMode))
    error('Measure.SourceMode must be char or string.');
end
if ~(ischar(Measure.FeedbackDisplayType) || isstring(Measure.FeedbackDisplayType))
    error('Measure.FeedbackDisplayType must be char or string.');
end

%% ===== CHECK NUMERIC FIELDS =====
% Numeric timing and power fields may be scalar or arrays depending on context.
numericFields = {'Power','ZRaw','ZClipped','ZSmoothed','FeedbackValue', ...
    'FeedbackTargetRadiusPx','FeedbackDisplayRadiusPx','FeedbackOuterRadiusPx', ...
    'FeedbackDisplayTime','SampleIndex','WindowStartSample','WindowEndSample', ...
    'WindowCenterSample'};
for i = 1:numel(numericFields)
    if ~isnumeric(Measure.(numericFields{i}))
        error('Measure.%s must be numeric.', numericFields{i});
    end
end

end
