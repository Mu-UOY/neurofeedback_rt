function Result = nf_save_live_self_test(Result, RTConfig, Source, Spatial, Baseline, RestingResult, TrialResult)
% NF_SAVE_LIVE_SELF_TEST Save live self-test audit files.
%
% USAGE:  Result = nf_save_live_self_test(Result, RTConfig, Source, Spatial, Baseline, RestingResult, TrialResult)

%% ===== PREPARE SESSION =====
% The audit folder is separate from raw MEG storage.
Session = nf_make_session_output_dir(RTConfig, 'live_self_test');
Result.OutputDir = Session.SessionDir;
Result.ReportMatPath = fullfile(Session.ReportsDir, 'live_self_test.mat');
Result.ReportTextPath = fullfile(Session.ReportsDir, 'live_self_test.txt');
Result.ConfigPath = fullfile(Session.ConfigDir, 'live_self_test_config.mat');
Result.SummaryCsvPath = fullfile(Session.ReportsDir, 'live_self_test_summary.csv');

%% ===== SAVE MAT AND CONFIG =====
% Do not serialize captured test-hook workspaces.
RTConfigForSave = local_config_for_save(RTConfig);
SavedAt = local_now_text(); %#ok<NASGU>
save(Result.ReportMatPath, 'Result', 'RTConfigForSave', 'Source', 'Spatial', ...
    'Baseline', 'RestingResult', 'TrialResult', 'SavedAt');
save(Result.ConfigPath, 'RTConfigForSave', 'SavedAt');

%% ===== SAVE SUMMARY CSV =====
% One-row CSV is convenient for quick run comparisons.
Summary = local_summary_table(Result, RTConfigForSave, Source, Spatial, RestingResult, TrialResult);
writetable(Summary, Result.SummaryCsvPath);

%% ===== SAVE TEXT REPORT =====
% Keep the MEG-room report readable and explicit.
fid = fopen(Result.ReportTextPath, 'w');
if fid < 0
    error('Could not open live self-test text report: %s', Result.ReportTextPath);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Live self-test\n');
fprintf(fid, 'RunID: %s\n', local_text(Result.RunID));
fprintf(fid, 'MEG site: %s\n', local_text(local_nested(RTConfigForSave, {'MEGRoom','SiteLabel'}, '')));
fprintf(fid, 'Operator: %s\n', local_text(local_nested(RTConfigForSave, {'MEGRoom','Operator'}, '')));
fprintf(fid, 'SubjectCode: %s\n', local_text(local_nested(RTConfigForSave, {'MEGRoom','SubjectCode'}, '')));
fprintf(fid, 'SessionLabel: %s\n', local_text(local_nested(RTConfigForSave, {'MEGRoom','SessionLabel'}, '')));
fprintf(fid, 'Source mode: %s\n', local_text(local_field(Source, 'Mode', '')));
fprintf(fid, 'Live adapter: %s\n', local_text(local_field(Source, 'LiveAdapter', '')));
fprintf(fid, 'Host: %s\n', local_text(local_nested(RTConfigForSave, {'Source','FieldTrip','Host'}, '')));
fprintf(fid, 'Port: %s\n', local_text(local_nested(RTConfigForSave, {'Source','FieldTrip','Port'}, [])));
fprintf(fid, 'Host origin: %s\n', local_text(local_nested(RTConfigForSave, {'Source','FieldTrip','SettingOrigin','Host'}, '')));
fprintf(fid, 'Port origin: %s\n', local_text(local_nested(RTConfigForSave, {'Source','FieldTrip','SettingOrigin','Port'}, '')));
fprintf(fid, 'TestBufferFcn used: %s\n', local_bool(local_has_test_hook(RTConfig)));
fprintf(fid, 'Fs: %s\n', local_text(local_field(Source, 'Fs', NaN)));
fprintf(fid, 'ChunkSamples: %s\n', local_text(RTConfigForSave.ChunkSamples));
fprintf(fid, 'PowerWindowSamples: %s\n', local_text(RTConfigForSave.PowerWindowSamples));
fprintf(fid, 'Target band: %s\n', local_target_band_text(RTConfigForSave));
fprintf(fid, 'Spatial matrix source: %s\n', local_text(local_field(Spatial, 'MatrixSource', '')));
fprintf(fid, 'Spatial IsIPS: %s\n', local_bool(local_field(Spatial, 'IsIPS', false)));
fprintf(fid, 'Spatial IsTechnicalFallback: %s\n', local_bool(local_field(Spatial, 'IsTechnicalFallback', false)));
fprintf(fid, 'Resting pass: %s\n', local_passfail(local_field(RestingResult, 'Pass', false)));
fprintf(fid, 'Resting valid measures: %s\n', local_text(local_field(RestingResult, 'NValidMeasures', NaN)));
fprintf(fid, 'Resting timeouts: %s\n', local_text(local_field(RestingResult, 'NTimeouts', NaN)));
fprintf(fid, 'Baseline path: %s\n', local_text(local_field(RestingResult, 'BaselinePath', '')));
fprintf(fid, 'Baseline quality: %s\n', local_text(local_nested(RestingResult, {'BaselineQuality','Status'}, '')));
fprintf(fid, 'Trial pass: %s\n', local_passfail(local_field(TrialResult, 'Pass', false)));
fprintf(fid, 'Trial valid measures: %s\n', local_text(local_field(TrialResult, 'NValidMeasures', NaN)));
fprintf(fid, 'Trial finite ZSmoothed: %s\n', local_text(local_field(TrialResult, 'NFiniteZSmoothed', NaN)));
fprintf(fid, 'Trial timeouts: %s\n', local_text(local_field(TrialResult, 'NTimeouts', NaN)));
fprintf(fid, 'Feedback mode: %s\n', local_text(local_nested(RTConfigForSave, {'Feedback','Mode'}, '')));
fprintf(fid, 'Feedback backend: %s\n', local_text(local_nested(RTConfigForSave, {'Feedback','Backend'}, '')));
fprintf(fid, 'Feedback map source: %s\n', local_text(local_nested(RTConfigForSave, {'Feedback','MapSource'}, '')));
fprintf(fid, 'Feedback updates: %s\n', local_text(local_field(TrialResult, 'NFeedbackUpdates', NaN)));
fprintf(fid, 'Feedback latency budget ms: %s\n', local_text(local_field(TrialResult, 'FeedbackLatencyBudgetMs', NaN)));
fprintf(fid, 'Feedback configured percentile: %s\n', ...
    local_text(local_field(TrialResult, 'FeedbackLatencyPercentile', NaN)));
fprintf(fid, 'Feedback configured-percentile latency ms: %s\n', ...
    local_text(local_field(TrialResult, ...
        'FeedbackLatencyConfiguredPercentileMs', NaN)));
fprintf(fid, 'Feedback latency p95/max ms: %s / %s\n', ...
    local_text(local_field(TrialResult, 'FeedbackLatencyMsP95', NaN)), ...
    local_text(local_field(TrialResult, 'FeedbackLatencyMsMax', NaN)));
fprintf(fid, 'Stop reason: %s\n', local_text(Result.StopReason));
fprintf(fid, 'Feedback closed: %s\n', local_bool(Result.FeedbackClosed));
fprintf(fid, 'Logger closed: %s\n', local_bool(Result.LoggerClosed));
fprintf(fid, 'Final PASS/FAIL: %s\n', local_passfail(Result.Pass));
fprintf(fid, 'Recommendation: %s\n', local_text(Result.Recommendation));

clear cleanupObj

end

function RTConfig = local_config_for_save(RTConfig)
% Avoid serializing function handles and captured test workspaces.
if isfield(RTConfig, 'Source') && isfield(RTConfig.Source, 'FieldTrip') && ...
        isfield(RTConfig.Source.FieldTrip, 'TestBufferFcn')
    RTConfig.Source.FieldTrip.TestBufferFcn = [];
end
end

function T = local_summary_table(Result, RTConfig, Source, Spatial, RestingResult, TrialResult)
% Build one-row CSV summary.
T = table({Result.RunID}, Result.Pass, {Result.StopReason}, {Result.Recommendation}, ...
    {local_field(Source, 'Mode', '')}, {local_field(Source, 'LiveAdapter', '')}, ...
    local_field(Source, 'Fs', NaN), RTConfig.ChunkSamples, RTConfig.PowerWindowSamples, ...
    {local_field(Spatial, 'MatrixSource', '')}, local_field(Spatial, 'IsIPS', false), ...
    local_field(Spatial, 'IsTechnicalFallback', false), local_field(RestingResult, 'Pass', false), ...
    local_field(RestingResult, 'NValidMeasures', NaN), local_field(TrialResult, 'Pass', false), ...
    local_field(TrialResult, 'NValidMeasures', NaN), local_field(TrialResult, 'NFeedbackUpdates', NaN), ...
    local_field(TrialResult, 'FeedbackLatencyPercentile', NaN), ...
    local_field(TrialResult, 'FeedbackLatencyConfiguredPercentileMs', NaN), ...
    local_field(TrialResult, 'FeedbackLatencyMsP95', NaN), ...
    local_field(TrialResult, 'FeedbackLatencyMsMax', NaN), ...
    'VariableNames', {'RunID','Pass','StopReason','Recommendation','SourceMode', ...
    'LiveAdapter','Fs','ChunkSamples','PowerWindowSamples','SpatialMatrixSource', ...
    'IsIPS','IsTechnicalFallback','RestingPass','RestingValidMeasures', ...
    'TrialPass','TrialValidMeasures','FeedbackUpdates','FeedbackLatencyPercentile', ...
    'FeedbackLatencyConfiguredPercentileMs','FeedbackLatencyMsP95', ...
    'FeedbackLatencyMsMax'});
end

function textValue = local_target_band_text(RTConfig)
% Format target band with optional label.
band = RTConfig.TargetBand;
label = local_field(RTConfig, 'TargetBandLabel', '');
if isempty(label)
    textValue = sprintf('[%g %g] Hz', band(1), band(2));
else
    textValue = sprintf('%s [%g %g] Hz', label, band(1), band(2));
end
end

function tf = local_has_test_hook(RTConfig)
% Detect whether caller supplied a FieldTrip test hook.
tf = isfield(RTConfig, 'Source') && isfield(RTConfig.Source, 'FieldTrip') && ...
    isfield(RTConfig.Source.FieldTrip, 'TestBufferFcn') && ...
    ~isempty(RTConfig.Source.FieldTrip.TestBufferFcn);
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function value = local_nested(S, path, defaultValue)
% Read optional nested field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    if ~isstruct(cursor) || ~isfield(cursor, path{iPath})
        return;
    end
    cursor = cursor.(path{iPath});
end
value = cursor;
end

function textValue = local_text(value)
% Convert scalar values to text.
if isempty(value)
    textValue = '';
elseif isnumeric(value) && isscalar(value)
    textValue = num2str(value);
elseif islogical(value) && isscalar(value)
    textValue = local_bool(value);
elseif ischar(value)
    textValue = value;
elseif isstring(value)
    textValue = char(value);
else
    textValue = '<non-scalar>';
end
end

function textValue = local_bool(value)
% Format logical-like values.
textValue = 'false';
if (islogical(value) && isscalar(value) && value) || ...
        (isnumeric(value) && isscalar(value) && value ~= 0)
    textValue = 'true';
end
end

function textValue = local_passfail(value)
% Format pass/fail values.
if (islogical(value) && isscalar(value) && value) || ...
        (isnumeric(value) && isscalar(value) && value ~= 0)
    textValue = 'PASS';
else
    textValue = 'FAIL';
end
end

function value = local_now_text()
% Return stable timestamp.
if exist('datetime', 'builtin') || exist('datetime', 'file')
    value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
else
    value = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
end
