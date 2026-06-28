function Data = nf_load_validation_data(RTConfig)
% NF_LOAD_VALIDATION_DATA Load a validation dataset into the canonical Data struct.
%
% USAGE:  Data = nf_load_validation_data(RTConfig)
%
% DESCRIPTION:
%     Loads a saved MAT dataset, normalizes accepted field layouts into the
%     canonical Data struct, validates dimensions and Fs, applies configured
%     sample bounds, and records loading metadata.

%% ===== CHECK DATASET PATH =====
% Validation replay needs an existing saved dataset file.
datasetPath = RTConfig.Source.DatasetPath;
if isempty(datasetPath)
    error('Set RTConfig.Source.DatasetPath before running validation.');
end
if exist(datasetPath, 'file') == 0
    error('Dataset file does not exist: %s', datasetPath);
end

%% ===== LOAD DATASET =====
% Accept either a prebuilt Data struct or top-level X/Fs-style variables.
loaded = load(datasetPath);
if isfield(loaded, 'Data')
    Data = loaded.Data;
else
    Data = struct();
    if ~isfield(loaded, 'X')
        error('Dataset must contain either Data or X.');
    end
    Data.X = loaded.X;

    if isfield(loaded, 'Fs')
        Data.Fs = loaded.Fs;
    else
        error('Dataset must contain Fs.');
    end

    if isfield(loaded, 'Time')
        Data.Time = loaded.Time;
    end
    if isfield(loaded, 'ChannelNames')
        Data.ChannelNames = loaded.ChannelNames;
    elseif isfield(loaded, 'ChannelLabels')
        Data.ChannelNames = loaded.ChannelLabels;
    end
    if isfield(loaded, 'Events')
        Data.Events = loaded.Events;
    end
end

%% ===== VALIDATE REQUIRED DATA FIELDS =====
% Data.X is always [channels x samples].
if ~isfield(Data, 'X') || ~isnumeric(Data.X) || ndims(Data.X) ~= 2
    error('Data.X must be a numeric [nChannels x nSamples] matrix.');
end

% Data.Fs must match RTConfig.Fs exactly enough for sample-level alignment.
if ~isfield(Data, 'Fs') || ~isscalar(Data.Fs) || ~isnumeric(Data.Fs) || ~isfinite(Data.Fs) || Data.Fs <= 0
    error('Data.Fs must be a finite positive numeric scalar.');
end
if abs(Data.Fs - RTConfig.Fs) > 1e-9
    error(['Data.Fs (%g) does not match RTConfig.Fs (%g). ', ...
        'Fix RTConfig.Fs or load a matching dataset before running validation.'], ...
        Data.Fs, RTConfig.Fs);
end

[nChannels, nSamples] = size(Data.X);

%% ===== NORMALIZE TIME VECTOR =====
% Missing time is generated from Fs; provided time is reshaped to a row.
if ~isfield(Data, 'Time') || isempty(Data.Time)
    Data.Time = (0:(nSamples - 1)) ./ Data.Fs;
else
    Data.Time = reshape(Data.Time, 1, []);
    if numel(Data.Time) ~= nSamples
        error('Data.Time length (%d) must match size(Data.X,2) (%d).', numel(Data.Time), nSamples);
    end
end

%% ===== NORMALIZE CHANNEL NAMES =====
% Missing labels get deterministic CH001-style names.
if ~isfield(Data, 'ChannelNames') || isempty(Data.ChannelNames)
    Data.ChannelNames = local_default_channel_names(nChannels);
else
    Data.ChannelNames = local_cellstr(Data.ChannelNames);
    if numel(Data.ChannelNames) ~= nChannels
        error('Data.ChannelNames length (%d) must match size(Data.X,1) (%d).', ...
            numel(Data.ChannelNames), nChannels);
    end
end

%% ===== NORMALIZE OPTIONAL FIELDS =====
% Downstream code can rely on Events and Metadata existing.
if ~isfield(Data, 'Events')
    Data.Events = [];
end
if ~isfield(Data, 'Metadata') || isempty(Data.Metadata)
    Data.Metadata = struct();
end

%% ===== APPLY SAMPLE RANGE =====
% Source bounds let validation replay only a segment of the saved dataset.
startSample = RTConfig.Source.StartSample;
if isempty(startSample) || ~isfinite(startSample)
    startSample = 1;
end
startSample = max(1, round(startSample));

endSample = RTConfig.Source.EndSample;
if isempty(endSample) || isinf(endSample)
    endSample = nSamples;
end
endSample = min(nSamples, round(endSample));

if endSample < startSample
    error('Invalid source sample range: [%d %d].', startSample, endSample);
end

Data.X = Data.X(:, startSample:endSample);
Data.Time = Data.Time(startSample:endSample);

%% ===== RECORD LOAD METADATA =====
% Preserve provenance and the exact sample range after trimming.
Data.Metadata.SourceFile = datasetPath;
Data.Metadata.LoadedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Data.Metadata.SampleRange = [startSample endSample];

%% ===== PRINT SUMMARY =====
% Match the concise validation-style status output.
if RTConfig.Debug.Verbose
    fprintf('Loaded validation data: %d channels, %d samples, Fs = %.9g Hz, duration = %.3f s\n', ...
        size(Data.X, 1), size(Data.X, 2), Data.Fs, size(Data.X, 2) ./ Data.Fs);
end

end

function names = local_default_channel_names(nChannels)
% Create deterministic labels when a dataset does not provide channel names.
names = cell(1, nChannels);
for i = 1:nChannels
    names{i} = sprintf('CH%03d', i);
end
end

function out = local_cellstr(in)
% Normalize MATLAB char, string, or cell channel labels to a row cell array.
if isstring(in)
    out = cellstr(in(:));
elseif ischar(in)
    out = cellstr(in);
elseif iscell(in)
    out = in(:);
else
    error('Channel names must be a cell array, string array, or char array.');
end
out = reshape(out, 1, []);
end
