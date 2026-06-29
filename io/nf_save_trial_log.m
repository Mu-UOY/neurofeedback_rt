function outFile = nf_save_trial_log(Measures, RTConfig, Baseline, TrialSummary)
% NF_SAVE_TRIAL_LOG Save simulated trial Measures and summary.
%
% USAGE:  outFile = nf_save_trial_log(Measures, RTConfig, Baseline, TrialSummary)
%
% DESCRIPTION:
%     Saves trial Measures, RTConfig, optional Baseline, and TrialSummary under
%     RTConfig.Paths.TrialsDir.

%% ===== PARSE INPUTS =====
% Baseline and TrialSummary are optional for direct helper use.
if nargin < 3
    Baseline = [];
end
if nargin < 4 || isempty(TrialSummary)
    TrialSummary = local_minimal_summary(Measures, Baseline);
end

%% ===== BUILD OUTPUT PATH =====
% Trial logs are timestamped and kept under the configured trials folder.
outDir = RTConfig.Paths.TrialsDir;
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

SavedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outFile = fullfile(outDir, ['trial_', stamp, '.mat']);

%% ===== FINALIZE SUMMARY =====
% Save OutputFile and SavedAt inside the TrialSummary variable.
TrialSummary.NMeasures = numel(Measures);
if ~isfield(TrialSummary, 'NValidMeasures')
    TrialSummary.NValidMeasures = local_nvalid(Measures);
end
if ~isfield(TrialSummary, 'NFeedbackValues')
    TrialSummary.NFeedbackValues = local_nfeedback(Measures);
end
if ~isfield(TrialSummary, 'BaselineConfigHash')
    TrialSummary.BaselineConfigHash = local_baseline_hash(Baseline);
end
TrialSummary.OutputFile = outFile;
TrialSummary.SavedAt = SavedAt;

%% ===== SAVE MAT FILE =====
% Save all trial artifacts for later audit and replay.
save(outFile, 'Measures', 'RTConfig', 'Baseline', 'TrialSummary', 'SavedAt');

end

function TrialSummary = local_minimal_summary(Measures, Baseline)
% Build a minimal summary when the caller did not provide one.
TrialSummary = struct();
TrialSummary.NMeasures = numel(Measures);
TrialSummary.NValidMeasures = local_nvalid(Measures);
TrialSummary.NFeedbackValues = local_nfeedback(Measures);
TrialSummary.ConfigHash = '';
TrialSummary.BaselineConfigHash = local_baseline_hash(Baseline);
end

function n = local_nvalid(Measures)
% Count valid Measures safely.
if isempty(Measures)
    n = 0;
else
    n = nnz([Measures.IsValid] == true);
end
end

function n = local_nfeedback(Measures)
% Count finite feedback values safely.
if isempty(Measures)
    n = 0;
else
    n = nnz(isfinite([Measures.FeedbackValue]));
end
end

function hash = local_baseline_hash(Baseline)
% Read baseline config hash with fallback.
hash = '';
if isstruct(Baseline) && isfield(Baseline, 'ConfigHash')
    hash = Baseline.ConfigHash;
end
end
