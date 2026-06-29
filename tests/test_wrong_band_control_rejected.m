function test_wrong_band_control_rejected()
% TEST_WRONG_BAND_CONTROL_REJECTED Check wrong-band false-positive control.

%% ===== BUILD WRONG-BAND BLOCKS =====
% The caller defines wrong-band settings; there is no generator mode string.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = 200;
RTConfig.Analysis.FastMode = true;
RTConfig.Analysis.MaxWrongBandMeanZ = 1.0;

BlockSettings = struct();
BlockSettings.Blocks = [ ...
    struct('Label', 'baseline',   'DurationSec', 2, 'InjectFreqHz', NaN, 'Amplitude', 0), ...
    struct('Label', 'wrong_band', 'DurationSec', 2, 'InjectFreqHz', 12,  'Amplitude', 1.0), ...
    struct('Label', 'off',        'DurationSec', 2, 'InjectFreqHz', NaN, 'Amplitude', 0)];
BlockSettings.NoiseAmplitude = 0.2;
BlockSettings.RandomSeed = 2;
BlockSettings.NChannels = 1;

[~, BlockInfo] = nf_make_synthetic_theta_dataset(RTConfig, BlockSettings);

%% ===== BUILD LOW-Z WRONG-BAND MEASURES =====
% A wrong-band injection should not create a target-theta positive.
Measures = local_measures_for_blocks(BlockInfo, [0.1 0.2 0.1]);
Results = struct();
Results.Step1.BandDetection.PeakFrequency = 12;
Results.Step1.BandDetection.PeakInsideTargetBand = false;

%% ===== VALIDATE WRONG-BAND CONTROL =====
% The control passes when no false positive is detected.
ThetaRecovery = nf_validate_theta_recovery(Results, [], Measures, BlockInfo, RTConfig);

assert(ThetaRecovery.FalsePositive == false, ...
    'Wrong-band control was incorrectly marked as a false positive.');
assert(ThetaRecovery.Pass == true, 'Wrong-band control should pass when no false positive exists.');
assert(ThetaRecovery.MeanZWrongBand < RTConfig.Analysis.MaxWrongBandMeanZ, ...
    'Wrong-band mean z exceeded the configured threshold.');
assert(strcmp(ThetaRecovery.MeanZByBlock.Labels{2}, 'wrong_band'), ...
    'Wrong-band label was not preserved in MeanZByBlock.');

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
