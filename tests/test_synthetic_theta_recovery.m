function test_synthetic_theta_recovery()
% TEST_SYNTHETIC_THETA_RECOVERY Check theta-on block recovery validation.

%% ===== BUILD FAST SYNTHETIC BLOCKS =====
% BlockInfo comes from the Step 2C synthetic dataset generator.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = 200;
RTConfig.Analysis.FastMode = true;
RTConfig.Analysis.MinThetaOnMinusOffZ = 0.5;

[~, BlockInfo] = nf_make_synthetic_theta_dataset(RTConfig);

%% ===== BUILD BLOCK-ALIGNED MEASURES =====
% ZSmoothed is the preferred recovery metric.
Measures = local_measures_for_blocks(BlockInfo, [0 1.4 0.1]);

Results = struct();
Results.Step1.BandDetection.PeakFrequency = 6;
Results.Step1.BandDetection.PeakInsideTargetBand = true;
Results.ConfigHash = 'THETA123';

%% ===== VALIDATE THETA RECOVERY =====
% theta_on should exceed baseline/theta_off by the configured margin.
ThetaRecovery = nf_validate_theta_recovery(Results, [], Measures, BlockInfo, RTConfig);

assert(ThetaRecovery.Pass == true, 'Theta recovery did not pass.');
assert(ThetaRecovery.ThetaOnMinusThetaOff > 0, ...
    'ThetaOnMinusThetaOff should be positive.');
assert(ThetaRecovery.ThetaOnMinusThetaOff >= RTConfig.Analysis.MinThetaOnMinusOffZ, ...
    'Theta recovery delta did not meet threshold.');
assert(strcmp(ThetaRecovery.MeanZByBlock.Labels{2}, 'theta_on'), ...
    'MeanZByBlock labels were not preserved.');
assert(strcmp(ThetaRecovery.ConfigHash, 'THETA123'), ...
    'ThetaRecovery.ConfigHash was not preserved.');

end

function Measures = local_measures_for_blocks(BlockInfo, zValues)
% Create one valid Measure at each block center.
nBlocks = numel(BlockInfo.Labels);
Measures = repmat(nf_measure_empty(), 1, nBlocks);
for iBlock = 1:nBlocks
    centerSample = round((BlockInfo.StartSample(iBlock) + BlockInfo.EndSample(iBlock)) ./ 2);
    Measures(iBlock).SampleIndex = centerSample;
    Measures(iBlock).WindowCenterSample = centerSample;
    Measures(iBlock).ZSmoothed = zValues(iBlock);
    Measures(iBlock).ZClipped = zValues(iBlock);
    Measures(iBlock).ZRaw = zValues(iBlock);
    Measures(iBlock).Power = zValues(iBlock) + 10;
    Measures(iBlock).IsValid = true;
end
end
