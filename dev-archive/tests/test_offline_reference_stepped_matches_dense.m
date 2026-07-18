function test_offline_reference_stepped_matches_dense()
% TEST_OFFLINE_REFERENCE_STEPPED_MATCHES_DENSE Check stepped reference equivalence.
%
% USAGE:  test_offline_reference_stepped_matches_dense()
%
% DESCRIPTION:
%     Builds dense and stepped offline references from the same synthetic data
%     and verifies every stepped window exactly matches the dense reference at
%     the same sample indices.

%% ===== CREATE SYNTHETIC DATA =====
% Use deterministic broadband data so window powers vary across time.
rng(41);
Fs = 100;
nSamples = 1000;
t = (0:(nSamples - 1)) ./ Fs;
X = [
    sin(2 .* pi .* 7 .* t) + 0.05 .* randn(1, nSamples)
    0.5 .* sin(2 .* pi .* 11 .* t + 0.3) + 0.05 .* randn(1, nSamples)
];

Data = struct();
Data.X = X;
Data.Fs = Fs;
Data.Time = t;
Data.ChannelNames = {'CH001','CH002'};
Data.Events = [];

%% ===== CONFIGURE REFERENCES =====
% Passthrough filtering isolates the reference window-stride behavior.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = Fs;
RTConfig.Filter.Type = 'none';
RTConfig.Filter.DiscardInitialSamples = 0;
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = 2;
RTConfig.TargetBand = [6 12];
RTConfig.PowerWindowSamples = 80;
RTConfig.ChunkSamples = 25;
RTConfig.BufferSamples = 160;
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = RTConfig.ChunkSamples;

RTConfigDense = RTConfig;
RTConfigDense.Validation.Step1.ReferenceStrideMode = 'dense';
RefDense = nf_make_offline_reference(Data, RTConfigDense);

RTConfigStep = RTConfig;
RTConfigStep.Validation.Step1.ReferenceStrideMode = 'step';
RTConfigStep.Validation.Step1.ReferenceStepSamples = RTConfig.ChunkSamples;
RefStep = nf_make_offline_reference(Data, RTConfigStep);

%% ===== COMPARE MATCHING WINDOWS =====
% Every stepped center must exist in dense mode with identical window bounds.
tolAbs = 1e-12;
tolRel = 1e-10;
matchedDensePower = NaN(size(RefStep.Power));

for iStep = 1:numel(RefStep.Power)
    idxDense = find(RefDense.WindowCenterSample == RefStep.WindowCenterSample(iStep), 1, 'first');
    assert(~isempty(idxDense), 'Stepped window center missing from dense reference.');

    assert(RefDense.WindowStartSample(idxDense) == RefStep.WindowStartSample(iStep), ...
        'WindowStartSample mismatch.');
    assert(RefDense.WindowEndSample(idxDense) == RefStep.WindowEndSample(iStep), ...
        'WindowEndSample mismatch.');
    assert(RefDense.WindowCenterSample(idxDense) == RefStep.WindowCenterSample(iStep), ...
        'WindowCenterSample mismatch.');

    absErr = abs(RefDense.Power(idxDense) - RefStep.Power(iStep));
    relErr = absErr ./ max(abs(RefDense.Power(idxDense)), eps);
    assert(absErr <= tolAbs || relErr <= tolRel, 'Stepped power does not match dense power.');

    matchedDensePower(iStep) = RefDense.Power(idxDense);
end

%% ===== CHECK AGREEMENT METRICS =====
% Shape and scale should be identical up to numerical precision.
keep = isfinite(matchedDensePower) & isfinite(RefStep.Power);
C = corrcoef(matchedDensePower(keep), RefStep.Power(keep));
rmse = sqrt(mean((matchedDensePower(keep) - RefStep.Power(keep)) .^ 2));

assert(C(1, 2) > 1 - 1e-12, 'Dense and stepped references are not perfectly correlated.');
assert(rmse <= 1e-12, 'Dense and stepped references have nontrivial RMSE.');
assert(nnz(keep) == numel(RefStep.Power), 'Not all stepped windows matched dense windows.');

end
