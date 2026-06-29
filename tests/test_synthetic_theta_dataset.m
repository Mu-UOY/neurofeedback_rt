function test_synthetic_theta_dataset()
% TEST_SYNTHETIC_THETA_DATASET Check Step 2C synthetic dataset generation.

%% ===== GENERATE FAST THETA-POSITIVE DATA =====
% Fast mode keeps this test independent of external data and GUI code.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;
RTConfig.Fs = 200;
RTConfig.Analysis.FastMode = true;

[Data, BlockInfo] = nf_make_synthetic_theta_dataset(RTConfig);

%% ===== CHECK DATA SCHEMA =====
% The generator should match the canonical replay/validation Data schema.
assert(isfield(Data, 'X') && isnumeric(Data.X), 'Data.X is missing.');
assert(isfield(Data, 'Fs') && Data.Fs == RTConfig.Fs, 'Data.Fs is missing or wrong.');
assert(isfield(Data, 'Time') && numel(Data.Time) == size(Data.X, 2), ...
    'Data.Time is missing or has the wrong length.');
assert(isfield(Data, 'ChannelNames') && numel(Data.ChannelNames) == size(Data.X, 1), ...
    'Data.ChannelNames is missing or has the wrong length.');
assert(isfield(Data, 'Metadata') && isfield(Data.Metadata, 'BlockInfo'), ...
    'Data.Metadata.BlockInfo is missing.');
assert(isequaln(Data.Metadata.BlockInfo, BlockInfo), ...
    'Data.Metadata.BlockInfo does not match returned BlockInfo.');

requiredBlockFields = {'Labels','StartSample','EndSample','StartTime','EndTime', ...
    'InjectFreqHz','Amplitude'};
for iField = 1:numel(requiredBlockFields)
    assert(isfield(BlockInfo, requiredBlockFields{iField}), ...
        'BlockInfo.%s is missing.', requiredBlockFields{iField});
end

%% ===== CHECK THETA INJECTION =====
% The theta_on block should carry a stronger 6 Hz component than off blocks.
baselineIdx = local_block_samples(BlockInfo, 'baseline');
thetaIdx = local_block_samples(BlockInfo, 'theta_on');
offIdx = local_block_samples(BlockInfo, 'theta_off');

baselineStrength = local_sine_strength(Data, baselineIdx, 6);
thetaStrength = local_sine_strength(Data, thetaIdx, 6);
offStrength = local_sine_strength(Data, offIdx, 6);

assert(thetaStrength > baselineStrength + 0.25, ...
    'Theta-on block did not exceed baseline 6 Hz strength.');
assert(thetaStrength > offStrength + 0.25, ...
    'Theta-on block did not exceed theta-off 6 Hz strength.');

%% ===== CHECK WRONG-BAND SETTINGS =====
% Wrong-band blocks are provided by the caller, not selected by a mode string.
BlockSettings = struct();
BlockSettings.Blocks = [ ...
    struct('Label', 'baseline',   'DurationSec', 2, 'InjectFreqHz', NaN, 'Amplitude', 0), ...
    struct('Label', 'wrong_band', 'DurationSec', 2, 'InjectFreqHz', 12,  'Amplitude', 1.0), ...
    struct('Label', 'off',        'DurationSec', 2, 'InjectFreqHz', NaN, 'Amplitude', 0)];
BlockSettings.NoiseAmplitude = 0.2;
BlockSettings.RandomSeed = 2;
BlockSettings.NChannels = 1;

[WrongData, WrongBlockInfo] = nf_make_synthetic_theta_dataset(RTConfig, BlockSettings);
assert(size(WrongData.X, 1) == 1, 'Wrong-band data used the wrong channel count.');
assert(strcmp(WrongBlockInfo.Labels{2}, 'wrong_band'), ...
    'Wrong-band block label was not preserved.');
assert(WrongBlockInfo.InjectFreqHz(2) == 12, ...
    'Wrong-band injection frequency was not preserved.');
assert(strcmp(WrongData.Events(2).Label, 'wrong_band'), ...
    'Wrong-band event label was not preserved.');

end

function idx = local_block_samples(BlockInfo, label)
% Return the inclusive sample index range for a named block.
match = find(strcmp(BlockInfo.Labels, label), 1, 'first');
assert(~isempty(match), 'Missing block label: %s', label);
idx = BlockInfo.StartSample(match):BlockInfo.EndSample(match);
end

function strength = local_sine_strength(Data, idx, freqHz)
% Compute absolute normalized correlation with a sine reference.
x = mean(Data.X(:, idx), 1);
x = x - mean(x);
s = sin(2 .* pi .* freqHz .* Data.Time(idx));
s = s - mean(s);
denom = sqrt(sum(x .^ 2) .* sum(s .^ 2));
if denom <= 0
    strength = 0;
else
    strength = abs(sum(x .* s) ./ denom);
end
end
