function [Data, BlockInfo] = nf_make_synthetic_theta_dataset(RTConfig, BlockSettings)
% NF_MAKE_SYNTHETIC_THETA_DATASET Create deterministic synthetic block data.
%
% USAGE:  [Data, BlockInfo] = nf_make_synthetic_theta_dataset(RTConfig)
%         [Data, BlockInfo] = nf_make_synthetic_theta_dataset(RTConfig, BlockSettings)
%
% DESCRIPTION:
%     Generates a canonical Data struct with block-wise sine injections for
%     fast theta-positive and wrong-band validation. This is an offline test
%     dataset generator only; it does not implement live acquisition.

%% ===== PARSE INPUTS =====
% BlockSettings is optional and defaults to a theta-positive design.
if nargin < 2
    BlockSettings = [];
end
if ~isstruct(RTConfig) || ~isfield(RTConfig, 'Fs')
    error('RTConfig.Fs is required.');
end

Fs = RTConfig.Fs;
if ~isscalar(Fs) || ~isnumeric(Fs) || ~isfinite(Fs) || Fs <= 0
    error('RTConfig.Fs must be a finite positive numeric scalar.');
end

fastMode = local_fast_mode(RTConfig);
BlockSettings = local_fill_block_settings(BlockSettings, fastMode);
blocks = BlockSettings.Blocks;
nBlocks = numel(blocks);
nChannels = BlockSettings.NChannels;

%% ===== SET RANDOM SEED =====
% Restore the caller's RNG state after deterministic generation.
if ~isempty(BlockSettings.RandomSeed)
    rngState = rng();
    cleanupObj = onCleanup(@() rng(rngState)); %#ok<NASGU>
    rng(round(BlockSettings.RandomSeed));
end

%% ===== RESOLVE BLOCK SAMPLE RANGES =====
% The rest of the repository uses 1-based inclusive sample indices.
blockSamples = zeros(1, nBlocks);
for iBlock = 1:nBlocks
    local_validate_block(blocks(iBlock), Fs);
    blockSamples(iBlock) = max(1, round(blocks(iBlock).DurationSec .* Fs));
end
totalSamples = sum(blockSamples);
Time = (0:(totalSamples - 1)) ./ Fs;

BlockInfo = struct();
BlockInfo.Labels = cell(1, nBlocks);
BlockInfo.StartSample = zeros(1, nBlocks);
BlockInfo.EndSample = zeros(1, nBlocks);
BlockInfo.StartTime = zeros(1, nBlocks);
BlockInfo.EndTime = zeros(1, nBlocks);
BlockInfo.InjectFreqHz = NaN(1, nBlocks);
BlockInfo.Amplitude = NaN(1, nBlocks);

Events = repmat(struct( ...
    'Type', 'block', ...
    'Label', '', ...
    'StartSample', NaN, ...
    'EndSample', NaN, ...
    'StartTime', NaN, ...
    'EndTime', NaN, ...
    'InjectFreqHz', NaN, ...
    'Amplitude', NaN), 1, nBlocks);

startSample = 1;
for iBlock = 1:nBlocks
    endSample = startSample + blockSamples(iBlock) - 1;
    label = char(blocks(iBlock).Label);

    BlockInfo.Labels{iBlock} = label;
    BlockInfo.StartSample(iBlock) = startSample;
    BlockInfo.EndSample(iBlock) = endSample;
    BlockInfo.StartTime(iBlock) = Time(startSample);
    BlockInfo.EndTime(iBlock) = Time(endSample);
    BlockInfo.InjectFreqHz(iBlock) = blocks(iBlock).InjectFreqHz;
    BlockInfo.Amplitude(iBlock) = blocks(iBlock).Amplitude;

    Events(iBlock).Label = label;
    Events(iBlock).StartSample = startSample;
    Events(iBlock).EndSample = endSample;
    Events(iBlock).StartTime = Time(startSample);
    Events(iBlock).EndTime = Time(endSample);
    Events(iBlock).InjectFreqHz = blocks(iBlock).InjectFreqHz;
    Events(iBlock).Amplitude = blocks(iBlock).Amplitude;

    startSample = endSample + 1;
end

%% ===== GENERATE BACKGROUND NOISE =====
% Smoothed Gaussian noise is dependency-free and more stable than pure white.
X = local_smoothed_noise(nChannels, totalSamples, BlockSettings.NoiseAmplitude);

%% ===== INJECT BLOCK SINE WAVES =====
% Each configured sine is injected into all synthetic channels.
for iBlock = 1:nBlocks
    freqHz = blocks(iBlock).InjectFreqHz;
    amplitude = blocks(iBlock).Amplitude;
    if isfinite(freqHz) && amplitude ~= 0
        idx = BlockInfo.StartSample(iBlock):BlockInfo.EndSample(iBlock);
        sineWave = amplitude .* sin(2 .* pi .* freqHz .* Time(idx));
        X(:, idx) = X(:, idx) + repmat(sineWave, nChannels, 1);
    end
end

%% ===== BUILD DATA STRUCT =====
% Match the canonical validation/source replay schema.
Data = struct();
Data.X = X;
Data.Fs = Fs;
Data.Time = Time;
Data.Events = Events;
Data.ChannelNames = local_channel_names(nChannels);
Data.Metadata = struct();
Data.Metadata.Generator = mfilename;
Data.Metadata.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Data.Metadata.BlockInfo = BlockInfo;
Data.Metadata.BlockSettings = BlockSettings;
Data.Metadata.NoiseModel = 'smoothed_gaussian';

end

function fastMode = local_fast_mode(RTConfig)
% Read Analysis.FastMode without requiring fully checked configs.
fastMode = false;
if isfield(RTConfig, 'Analysis') && isfield(RTConfig.Analysis, 'FastMode') && ...
        ~isempty(RTConfig.Analysis.FastMode)
    fastMode = logical(RTConfig.Analysis.FastMode);
end
end

function BlockSettings = local_fill_block_settings(BlockSettings, fastMode)
% Fill optional block settings without overriding caller-provided values.
defaults = local_default_block_settings(fastMode);
if isempty(BlockSettings)
    BlockSettings = struct();
end
if ~isstruct(BlockSettings)
    error('BlockSettings must be a struct.');
end

if ~isfield(BlockSettings, 'Blocks') || isempty(BlockSettings.Blocks)
    BlockSettings.Blocks = defaults.Blocks;
end
if ~isfield(BlockSettings, 'NoiseAmplitude') || isempty(BlockSettings.NoiseAmplitude)
    BlockSettings.NoiseAmplitude = defaults.NoiseAmplitude;
end
if ~isfield(BlockSettings, 'RandomSeed')
    BlockSettings.RandomSeed = defaults.RandomSeed;
end
if ~isfield(BlockSettings, 'NChannels') || isempty(BlockSettings.NChannels)
    BlockSettings.NChannels = defaults.NChannels;
end

local_validate_block_settings(BlockSettings);
end

function BlockSettings = local_default_block_settings(fastMode)
% Default theta-positive design with shorter durations in fast mode.
durationSec = 10;
if fastMode
    durationSec = 2;
end

BlockSettings = struct();
BlockSettings.Blocks = [ ...
    struct('Label', 'baseline',  'DurationSec', durationSec, 'InjectFreqHz', NaN, 'Amplitude', 0), ...
    struct('Label', 'theta_on',  'DurationSec', durationSec, 'InjectFreqHz', 6,   'Amplitude', 1.0), ...
    struct('Label', 'theta_off', 'DurationSec', durationSec, 'InjectFreqHz', NaN, 'Amplitude', 0)];
BlockSettings.NoiseAmplitude = 0.2;
BlockSettings.RandomSeed = 1;
BlockSettings.NChannels = 1;
end

function local_validate_block_settings(BlockSettings)
% Validate top-level generator settings.
if ~isfield(BlockSettings, 'Blocks') || ~isstruct(BlockSettings.Blocks) || isempty(BlockSettings.Blocks)
    error('BlockSettings.Blocks must be a nonempty struct array.');
end
if ~isscalar(BlockSettings.NoiseAmplitude) || ~isnumeric(BlockSettings.NoiseAmplitude) || ...
        ~isfinite(BlockSettings.NoiseAmplitude) || BlockSettings.NoiseAmplitude < 0
    error('BlockSettings.NoiseAmplitude must be a finite nonnegative scalar.');
end
if ~isempty(BlockSettings.RandomSeed)
    seed = BlockSettings.RandomSeed;
    if ~isscalar(seed) || ~isnumeric(seed) || ~isfinite(seed) || seed < 0 || seed ~= round(seed)
        error('BlockSettings.RandomSeed must be empty or a finite nonnegative integer scalar.');
    end
end
if ~isscalar(BlockSettings.NChannels) || ~isnumeric(BlockSettings.NChannels) || ...
        ~isfinite(BlockSettings.NChannels) || BlockSettings.NChannels < 1 || ...
        BlockSettings.NChannels ~= round(BlockSettings.NChannels)
    error('BlockSettings.NChannels must be a positive integer scalar.');
end
end

function local_validate_block(Block, Fs)
% Validate one block definition.
required = {'Label','DurationSec','InjectFreqHz','Amplitude'};
for iField = 1:numel(required)
    if ~isfield(Block, required{iField})
        error('Each block must define %s.', required{iField});
    end
end
if ~(ischar(Block.Label) || isstring(Block.Label)) || isempty(char(Block.Label))
    error('Block.Label must be a nonempty char or string.');
end
if ~isscalar(Block.DurationSec) || ~isnumeric(Block.DurationSec) || ...
        ~isfinite(Block.DurationSec) || Block.DurationSec <= 0
    error('Block.DurationSec must be a finite positive scalar.');
end
freqHz = Block.InjectFreqHz;
if ~(isscalar(freqHz) && isnumeric(freqHz) && (isnan(freqHz) || ...
        (isfinite(freqHz) && freqHz >= 0 && freqHz < Fs ./ 2)))
    error('Block.InjectFreqHz must be NaN or a finite scalar below Nyquist.');
end
if ~isscalar(Block.Amplitude) || ~isnumeric(Block.Amplitude) || ~isfinite(Block.Amplitude)
    error('Block.Amplitude must be a finite numeric scalar.');
end
end

function X = local_smoothed_noise(nChannels, nSamples, noiseAmplitude)
% Generate deterministic smoothed Gaussian noise after rng seeding.
if noiseAmplitude == 0
    X = zeros(nChannels, nSamples);
    return;
end

white = randn(nChannels, nSamples);
alpha = 0.95;
X = filter(1 - alpha, [1 -alpha], white, [], 2);
channelStd = std(X, 0, 2);
channelStd(~isfinite(channelStd) | channelStd <= 0) = 1;
X = bsxfun(@rdivide, X, channelStd);
X = noiseAmplitude .* X;
end

function names = local_channel_names(nChannels)
% Create deterministic CH001-style labels.
names = cell(1, nChannels);
for iChannel = 1:nChannels
    names{iChannel} = sprintf('CH%03d', iChannel);
end
end
