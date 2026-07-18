function Data = nf_export_brainstorm_ctf_to_validation_mat(rawDsPath, outFile, varargin)
% NF_EXPORT_BRAINSTORM_CTF_TO_VALIDATION_MAT Export raw CTF MEG to validation MAT.
%
% USAGE:
%     Data = nf_export_brainstorm_ctf_to_validation_mat(rawDsPath, outFile)
%     Data = nf_export_brainstorm_ctf_to_validation_mat(rawDsPath, outFile, ...
%         'timeWindow', [0 120], 'channelTarget', 'MEG', 'exportMethod', 'auto')
%
% DESCRIPTION:
%     Reads the raw Brainstorm Introduction CTF tutorial dataset through a
%     toolbox reader and saves an unfiltered canonical validation MAT file:
%         Data.X              [channels x samples]
%         Data.Fs             sampling rate
%         Data.Time           sample times
%         Data.ChannelNames   channel labels
%         Data.Events         event structure, when available
%         Data.Metadata       raw-export provenance
%
%     No filtering, detrending, demeaning, baseline correction, artifact
%     correction, inverse modeling, scout mapping, or event protocol logic is
%     applied here.

%% ===== PARSE INPUTS =====
% Keep external toolbox paths out of source code. The caller must add
% FieldTrip or Brainstorm to the MATLAB path before calling this function.
if nargin < 1 || isempty(rawDsPath)
    error('rawDsPath is required.');
end
if nargin < 2 || isempty(outFile)
    error('outFile is required.');
end

p = inputParser();
p.FunctionName = mfilename;
addRequired(p, 'rawDsPath', @(x) ischar(x) || isstring(x));
addRequired(p, 'outFile', @(x) ischar(x) || isstring(x));
addParameter(p, 'timeWindow', [0 120], @local_is_time_window);
addParameter(p, 'channelTarget', 'MEG', @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'exportMethod', 'auto', @(x) ischar(x) || isstring(x));
parse(p, rawDsPath, outFile, varargin{:});

rawDsPath = char(p.Results.rawDsPath);
outFile = char(p.Results.outFile);
timeWindow = double(p.Results.timeWindow);
channelTarget = p.Results.channelTarget;
exportMethod = lower(char(p.Results.exportMethod));

if exist(rawDsPath, 'dir') == 0 && exist(rawDsPath, 'file') == 0
    error('Raw CTF dataset path does not exist: %s', rawDsPath);
end
if ~ismember(exportMethod, {'auto','fieldtrip','brainstorm'})
    error('exportMethod must be auto, fieldtrip, or brainstorm.');
end

%% ===== EXPORT RAW DATA =====
% Auto mode prefers FieldTrip because it can read raw CTF folders directly.
switch exportMethod
    case 'auto'
        Data = local_export_auto(rawDsPath, timeWindow, channelTarget);

    case 'fieldtrip'
        Data = local_export_fieldtrip(rawDsPath, timeWindow, channelTarget);

    case 'brainstorm'
        Data = local_export_brainstorm(rawDsPath, timeWindow, channelTarget);
end

%% ===== SAVE CANONICAL MAT FILE =====
% Save both Data and top-level fields so existing loaders can accept the file.
outDir = fileparts(outFile);
if ~isempty(outDir) && exist(outDir, 'dir') == 0
    mkdir(outDir);
end

X = Data.X; %#ok<NASGU>
Fs = Data.Fs; %#ok<NASGU>
Time = Data.Time; %#ok<NASGU>
ChannelNames = Data.ChannelNames; %#ok<NASGU>
Events = Data.Events; %#ok<NASGU>
Metadata = Data.Metadata; %#ok<NASGU>

save(outFile, 'Data', 'X', 'Fs', 'Time', 'ChannelNames', 'Events', 'Metadata', '-v7.3');

fprintf('Exported raw validation data: %s\n', outFile);
fprintf('  Method:      %s\n', Data.Metadata.ExportMethod);
fprintf('  Channels:    %d\n', size(Data.X, 1));
fprintf('  Samples:     %d\n', size(Data.X, 2));
fprintf('  Fs:          %.9g Hz\n', Data.Fs);

end

function Data = local_export_auto(rawDsPath, timeWindow, channelTarget)
% Try FieldTrip first, then Brainstorm if it is present on the MATLAB path.
fieldTripError = [];
if local_has_fieldtrip()
    try
        Data = local_export_fieldtrip(rawDsPath, timeWindow, channelTarget);
        return;
    catch ME
        fieldTripError = ME;
    end
end

if local_has_brainstorm()
    try
        Data = local_export_brainstorm(rawDsPath, timeWindow, channelTarget);
        return;
    catch ME
        if ~isempty(fieldTripError)
            error('Auto export failed. FieldTrip error: %s Brainstorm error: %s', ...
                fieldTripError.message, ME.message);
        end
        rethrow(ME);
    end
end

if ~isempty(fieldTripError)
    error('Auto export failed. FieldTrip was found but failed: %s', fieldTripError.message);
end
error(['Auto export failed. Add FieldTrip to the MATLAB path and call ft_defaults, ', ...
    'or request exportMethod=''fieldtrip'' after FieldTrip is available.']);
end

function Data = local_export_fieldtrip(rawDsPath, timeWindow, channelTarget)
% Use FieldTrip raw readers without any preprocessing options that modify data.
local_require_fieldtrip();

ft_defaults();
hdr = ft_read_header(rawDsPath);
Fs = local_header_fs(hdr);

startSample = max(1, floor(timeWindow(1) .* Fs) + 1);
requestedEndSample = round(timeWindow(2) .* Fs);
if requestedEndSample < startSample
    error('timeWindow [%g %g] does not contain any samples at Fs = %g.', ...
        timeWindow(1), timeWindow(2), Fs);
end

knownTotalSamples = local_known_total_samples(hdr);
endSample = requestedEndSample;
if ~isempty(knownTotalSamples)
    if startSample > knownTotalSamples
        error('Requested start sample %d exceeds available samples %d.', ...
            startSample, knownTotalSamples);
    end
    endSample = min(endSample, knownTotalSamples);
end

cfg = [];
cfg.dataset = rawDsPath;
cfg.channel = channelTarget;
cfg.continuous = 'yes';
cfg.trl = [startSample endSample 0];

try
    ftData = ft_preprocessing(cfg);
catch ME
    error(['FieldTrip raw export failed for sample range [%d %d]. ', ...
        'No fallback preprocessing was applied. Original error: %s'], ...
        startSample, endSample, ME.message);
end

[X, Time, ChannelNames] = local_unpack_fieldtrip_data(ftData);
if isempty(X)
    error('FieldTrip returned no samples for the requested CTF export.');
end

Data = struct();
Data.X = double(X);
Data.Fs = Fs;
Data.Time = reshape(Time, 1, []);
Data.ChannelNames = reshape(ChannelNames, 1, []);
Data.Events = [];
if isfield(ftData, 'cfg') && isfield(ftData.cfg, 'event')
    Data.Events = ftData.cfg.event;
end

Data.Metadata = local_metadata_template(rawDsPath, 'fieldtrip', timeWindow, channelTarget);
Data.Metadata.OriginalFs = Fs;
Data.Metadata.OriginalNSamples = local_original_nsamples(hdr, knownTotalSamples);
Data.Metadata.OriginalNChannels = local_original_nchannels(hdr);
Data.Metadata.ExportedSampleRange = [startSample, startSample + size(Data.X, 2) - 1];
Data.Metadata.Notes = ['Raw MEG export through FieldTrip ft_preprocessing. ', ...
    'No filters, demeaning, detrending, baseline correction, or artifact correction applied.'];

local_validate_data(Data);
end

function Data = local_export_brainstorm(rawDsPath, timeWindow, channelTarget) %#ok<INUSD>
% Brainstorm database import/export is intentionally not guessed here.
if ~local_has_brainstorm()
    error('Brainstorm is not on the MATLAB path.');
end

error(['Brainstorm direct raw CTF export is not implemented for this bridge. ', ...
    'Use exportMethod=''fieldtrip'' with FieldTrip on the MATLAB path.']);
end

function local_require_fieldtrip()
% FieldTrip must already be available on the MATLAB path.
requiredFunctions = {'ft_defaults','ft_read_header','ft_preprocessing'};
missing = {};
for iFunction = 1:numel(requiredFunctions)
    if exist(requiredFunctions{iFunction}, 'file') == 0
        missing{end + 1} = requiredFunctions{iFunction}; %#ok<AGROW>
    end
end
if ~isempty(missing)
    error('FieldTrip is required for raw CTF export. Missing function(s): %s.', ...
        strjoin(missing, ', '));
end
end

function tf = local_has_fieldtrip()
% Check functions rather than hardcoding toolbox paths.
tf = exist('ft_defaults', 'file') ~= 0 && ...
    exist('ft_read_header', 'file') ~= 0 && ...
    exist('ft_preprocessing', 'file') ~= 0;
end

function tf = local_has_brainstorm()
% Brainstorm can be on the path without being started.
tf = exist('brainstorm', 'file') ~= 0;
end

function Fs = local_header_fs(hdr)
% Accept standard FieldTrip header sampling-rate fields.
if isfield(hdr, 'Fs')
    Fs = hdr.Fs;
elseif isfield(hdr, 'fsample')
    Fs = hdr.fsample;
else
    error('FieldTrip header does not contain Fs or fsample.');
end
if ~isnumeric(Fs) || ~isscalar(Fs) || ~isfinite(Fs) || Fs <= 0
    error('FieldTrip header sampling rate is invalid.');
end
Fs = double(Fs);
end

function nSamples = local_known_total_samples(hdr)
% CTF headers can report samples per trial, so only infer total when nTrials is clear.
nSamples = [];
if isfield(hdr, 'nSamples') && isfield(hdr, 'nTrials') && ...
        isnumeric(hdr.nSamples) && isnumeric(hdr.nTrials) && ...
        isscalar(hdr.nSamples) && isscalar(hdr.nTrials) && ...
        isfinite(hdr.nSamples) && isfinite(hdr.nTrials) && hdr.nSamples > 0 && hdr.nTrials > 1
    nSamples = round(double(hdr.nSamples) .* double(hdr.nTrials));
end
end

function nSamples = local_original_nsamples(hdr, knownTotalSamples)
% Preserve the safest available estimate of original sample count.
if ~isempty(knownTotalSamples)
    nSamples = knownTotalSamples;
elseif isfield(hdr, 'nSamples') && isnumeric(hdr.nSamples) && isscalar(hdr.nSamples)
    nSamples = double(hdr.nSamples);
else
    nSamples = NaN;
end
end

function nChannels = local_original_nchannels(hdr)
% Preserve original header channel count when labels are available.
if isfield(hdr, 'label')
    nChannels = numel(hdr.label);
elseif isfield(hdr, 'nChans')
    nChannels = double(hdr.nChans);
else
    nChannels = NaN;
end
end

function [X, Time, ChannelNames] = local_unpack_fieldtrip_data(ftData)
% FieldTrip returns trials as cell arrays; concatenate only compatible trials.
if ~isstruct(ftData) || ~isfield(ftData, 'trial') || isempty(ftData.trial)
    error('FieldTrip output does not contain trial data.');
end
if ~isfield(ftData, 'label') || isempty(ftData.label)
    error('FieldTrip output does not contain channel labels.');
end

ChannelNames = cellstr(ftData.label(:));
X = [];
Time = [];

for iTrial = 1:numel(ftData.trial)
    trialX = ftData.trial{iTrial};
    if size(trialX, 1) ~= numel(ChannelNames)
        error('FieldTrip trial %d channel count does not match labels.', iTrial);
    end

    if isfield(ftData, 'time') && numel(ftData.time) >= iTrial && ~isempty(ftData.time{iTrial})
        trialTime = reshape(ftData.time{iTrial}, 1, []);
    else
        trialTime = (0:(size(trialX, 2) - 1)) ./ ftData.fsample;
    end
    if numel(trialTime) ~= size(trialX, 2)
        error('FieldTrip trial %d time length does not match sample count.', iTrial);
    end

    X = [X, trialX]; %#ok<AGROW>
    Time = [Time, trialTime]; %#ok<AGROW>
end
end

function Metadata = local_metadata_template(rawDsPath, method, timeWindow, channelTarget)
% Build provenance fields shared by all export methods.
Metadata = struct();
Metadata.SourceRawPath = rawDsPath;
Metadata.ExportMethod = method;
Metadata.TimeWindow = timeWindow;
Metadata.ChannelTarget = channelTarget;
Metadata.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
Metadata.IsRawExport = true;
Metadata.PreFilteringApplied = false;
Metadata.OriginalFs = NaN;
Metadata.OriginalNSamples = NaN;
Metadata.OriginalNChannels = NaN;
Metadata.ExportedSampleRange = [NaN NaN];
Metadata.Notes = '';
end

function local_validate_data(Data)
% Validate the canonical export before saving.
if ~isfield(Data, 'X') || ~isnumeric(Data.X) || ndims(Data.X) ~= 2 || isempty(Data.X)
    error('Exported Data.X must be a nonempty numeric [channels x samples] matrix.');
end
if ~isfield(Data, 'Fs') || ~isscalar(Data.Fs) || ~isfinite(Data.Fs) || Data.Fs <= 0
    error('Exported Data.Fs must be a finite positive scalar.');
end
if ~isfield(Data, 'Time') || numel(Data.Time) ~= size(Data.X, 2)
    error('Exported Data.Time length must match Data.X samples.');
end
if ~isfield(Data, 'ChannelNames') || numel(Data.ChannelNames) ~= size(Data.X, 1)
    error('Exported Data.ChannelNames length must match Data.X channels.');
end
if ~isfield(Data, 'Metadata') || ~isfield(Data.Metadata, 'PreFilteringApplied') || Data.Metadata.PreFilteringApplied
    error('Export metadata must explicitly state that no prefiltering was applied.');
end
end

function tf = local_is_time_window(x)
% A time window is [startSeconds endSeconds] with end after start.
tf = isnumeric(x) && numel(x) == 2 && all(isfinite(x)) && x(1) >= 0 && x(2) > x(1);
end
