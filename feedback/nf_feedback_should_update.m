function tf = nf_feedback_should_update(Measure, RT, RTConfig)
% NF_FEEDBACK_SHOULD_UPDATE Decide whether to map feedback for a Measure.
%
% USAGE:  tf = nf_feedback_should_update(Measure, RT, RTConfig)
%
% DESCRIPTION:
%     Step 2B only decides update cadence for non-UI debug feedback values.

%% ===== REJECT INVALID OR DISABLED FEEDBACK =====
% Feedback mapping happens only for valid Measures and non-none mode.
tf = false;
if isempty(Measure) || ~isfield(Measure, 'IsValid') || ~Measure.IsValid
    return;
end
if ~isfield(RTConfig, 'Feedback') || ~isfield(RTConfig.Feedback, 'Mode') || ...
        strcmp(RTConfig.Feedback.Mode, 'none')
    return;
end

%% ===== CHECK UPDATE CADENCE =====
% nf_rt_process_chunk has already incremented RT.SampleCounter.TotalValid.
totalValid = local_get_nested(RT, {'SampleCounter','TotalValid'}, 0);
updateEvery = RTConfig.Feedback.UpdateEveryNValidMeasures;
tf = mod(totalValid, updateEvery) == 0;

end

function value = local_get_nested(S, path, defaultValue)
% Read nested field with fallback.
value = defaultValue;
current = S;
for iPath = 1:numel(path)
    if ~isstruct(current) || ~isfield(current, path{iPath})
        return;
    end
    current = current.(path{iPath});
end
value = current;
end
