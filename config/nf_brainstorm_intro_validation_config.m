function RTConfig = nf_brainstorm_intro_validation_config(exportedMatPath, Fs, nChannels, targetBand, varargin)
% NF_BRAINSTORM_INTRO_VALIDATION_CONFIG Build config for tutorial raw MEG validation.
%
% USAGE:
%     RTConfig = nf_brainstorm_intro_validation_config(exportedMatPath, Fs, nChannels)
%     RTConfig = nf_brainstorm_intro_validation_config(exportedMatPath, Fs, nChannels, targetBand)
%     RTConfig = nf_brainstorm_intro_validation_config(..., 'BrainstormMode', 'bst_function')
%
% DESCRIPTION:
%     Creates a first-pass Step 1 validation configuration for a raw MEG MAT
%     exported from the Brainstorm Introduction CTF tutorial dataset. This
%     helper does not require FieldTrip or Brainstorm and does not call
%     nf_check_config.

%% ===== PARSE INPUTS =====
% Defaults match the Brainstorm Introduction tutorial export target.
if nargin < 1 || isempty(exportedMatPath)
    exportedMatPath = '';
end
if nargin < 2 || isempty(Fs)
    Fs = 600;
end
if nargin < 3
    nChannels = [];
end
if nargin < 4 || isempty(targetBand)
    targetBand = [8 12];
end

exportedMatPath = char(exportedMatPath);
Fs = double(Fs);
targetBand = double(targetBand);

if ~isscalar(Fs) || ~isfinite(Fs) || Fs <= 0
    error('Fs must be a finite positive scalar.');
end
if ~isempty(nChannels)
    nChannels = double(nChannels);
    if ~isscalar(nChannels) || ~isfinite(nChannels) || nChannels <= 0
        error('nChannels must be empty or a finite positive scalar.');
    end
end
if ~isnumeric(targetBand) || numel(targetBand) ~= 2 || targetBand(2) <= targetBand(1)
    error('targetBand must be [low high] with high > low.');
end

%% ===== PARSE OPTIONS =====
% Defaults preserve portable test behavior: Brainstorm comparison is skipped.
p = inputParser();
p.FunctionName = mfilename;
addParameter(p, 'BrainstormMode', 'skip', @(x) ischar(x) || isstring(x));
addParameter(p, 'RequireBrainstormForPass', false, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'BrainstormPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'FieldTripPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'BrainstormMethod', 'bst-hfilter-2019', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

brainstormMode = char(p.Results.BrainstormMode);
requireBrainstormForPass = logical(p.Results.RequireBrainstormForPass);
brainstormPath = char(p.Results.BrainstormPath);
fieldTripPath = char(p.Results.FieldTripPath);
brainstormMethod = char(p.Results.BrainstormMethod);

%% ===== START FROM DEFAULT CONFIG =====
% Keep shared defaults centralized and override only tutorial-specific fields.
RTConfig = nf_default_config();

%% ===== SOURCE AND SAMPLING =====
% The exported MAT file is replayed in simulated-online mode.
RTConfig.Source.DatasetPath = exportedMatPath;
RTConfig.Fs = Fs;
RTConfig.TargetBand = reshape(targetBand, 1, []);

RTConfig.ChunkSamples = round(0.5 .* Fs);
RTConfig.PowerWindowSamples = round(4.0 .* Fs);
RTConfig.BufferSamples = round(8.0 .* Fs);

%% ===== FILTER AND SPATIAL SETTINGS =====
% Use the first-version causal IIR/SOS filter and identity spatial mapping.
RTConfig.Filter.Type = 'iir_sos';
RTConfig.Spatial.Mode = 'identity';
RTConfig.Spatial.NChannels = nChannels;

%% ===== STEP 1 VALIDATION SETTINGS =====
% Brainstorm comparison is explicitly skipped for this raw-reader bridge.
RTConfig.Validation.Step1.WindowSamples = RTConfig.PowerWindowSamples;
RTConfig.Validation.Step1.StepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.ReferenceStrideMode = 'step';
RTConfig.Validation.Step1.ReferenceStepSamples = RTConfig.ChunkSamples;
RTConfig.Validation.Step1.Brainstorm.Mode = brainstormMode;
RTConfig.Validation.Step1.Brainstorm.RequireForPass = requireBrainstormForPass;
RTConfig.Validation.Step1.FFT.ReferenceBands = [
    4 8
    8 12
    13 30
    30 59
];
RTConfig.Validation.Step1.BandDetection.Enable = true;
RTConfig.Validation.Step1.Controls.Enable = false;

%% ===== BRAINSTORM/FIELDTRIP OPTIONS =====
% Paths are stored for explicit local Brainstorm comparison runners.
RTConfig.Brainstorm.Path = brainstormPath;
RTConfig.Brainstorm.FieldTripPath = fieldTripPath;
RTConfig.Brainstorm.OfflineBandpassFunction = 'bst_bandpass_hfilter';
RTConfig.Brainstorm.OfflineBandpassMethod = brainstormMethod;

end
