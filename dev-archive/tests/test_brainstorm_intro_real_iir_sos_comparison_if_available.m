function test_brainstorm_intro_real_iir_sos_comparison_if_available()
% TEST_BRAINSTORM_INTRO_REAL_IIR_SOS_COMPARISON_IF_AVAILABLE Run local real check.

%% ===== CHECK LOCAL PATHS =====
% This test is local-machine optional and skips cleanly elsewhere.
rawDsPath = 'C:\Users\yango\Documents\sample_introduction\data\S01_AEF_20131218_01_600Hz.ds';
brainstormPath = 'C:\Users\yango\Documents\brainstorm3';
fieldTripPath = 'C:\Users\yango\Documents\fieldtrip';

if exist(rawDsPath, 'dir') == 0 || exist(brainstormPath, 'dir') == 0 || ...
        exist(fieldTripPath, 'dir') == 0
    fprintf('[SKIP] Local Brainstorm tutorial raw data/toolbox paths unavailable.\n');
    return;
end

%% ===== RUN EXPLICIT LOCAL CHECK =====
% The runner owns toolbox setup and asserts the comparison is not skipped.
Results = nf_run_brainstorm_iir_sos_check( ...
    'rawDsPath', rawDsPath, ...
    'brainstormPath', brainstormPath, ...
    'fieldTripPath', fieldTripPath, ...
    'timeWindow', [0 60]);

%% ===== ASSERT PASS =====
% Local raw Brainstorm comparison should pass with high z-correlation.
iirResults = Results.Step1.IIRSOSComparison;
assert(strcmp(iirResults.Status, 'PASS'), ...
    'Real Brainstorm IIR/SOS comparison did not PASS.');
assert(iirResults.Compare.ZCorrelation >= 0.90, ...
    'Real Brainstorm IIR/SOS ZCorrelation %.6f is below 0.90.', ...
    iirResults.Compare.ZCorrelation);

end
