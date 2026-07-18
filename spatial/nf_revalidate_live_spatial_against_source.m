function Spatial = nf_revalidate_live_spatial_against_source(Spatial, Source, RTConfig)
% NF_REVALIDATE_LIVE_SPATIAL_AGAINST_SOURCE Validate live spatial metadata.
%
% USAGE:  Spatial = nf_revalidate_live_spatial_against_source(Spatial, Source, RTConfig)
%
% DESCRIPTION:
%     Rejects a prepared live spatial matrix if the current live header no
%     longer matches its channel count, channel order, header hash, or
%     comparable correction-state fields.

%% ===== CHECK STRUCT AND MATRIX =====
% The RT core needs a finite 2-D channels-to-signals matrix.
if nargin < 3
    RTConfig = struct();
end
if ~isstruct(Spatial) || isempty(Spatial)
    error('Spatial must be a nonempty struct.');
end
if ~isfield(Spatial, 'CombinedMatrix') || ~isnumeric(Spatial.CombinedMatrix) || ...
        ndims(Spatial.CombinedMatrix) ~= 2 || isempty(Spatial.CombinedMatrix)
    error('Spatial.CombinedMatrix must be a nonempty numeric 2-D matrix.');
end
if any(~isfinite(Spatial.CombinedMatrix(:)))
    error('Spatial.CombinedMatrix must contain only finite values.');
end

%% ===== CHECK LIVE SOURCE HEADER =====
% Live dry-run timing is fixed at the Step 3 live acquisition contract.
if isstruct(Source) && isfield(Source, 'Fs') && ~isempty(Source.Fs) && ...
        isnumeric(Source.Fs) && isscalar(Source.Fs) && abs(Source.Fs - 2400) > 1e-9
    error('Live spatial validation expected Source.Fs = 2400 Hz, got %g.', Source.Fs);
end
if isfield(RTConfig, 'Fs') && ~isempty(RTConfig.Fs) && isnumeric(RTConfig.Fs) && ...
        isscalar(RTConfig.Fs) && abs(RTConfig.Fs - 2400) > 1e-9
    error('Live spatial validation expected RTConfig.Fs = 2400 Hz, got %g.', RTConfig.Fs);
end

[channelNames, nChannels] = local_source_channel_names(Source);
if size(Spatial.CombinedMatrix, 2) ~= nChannels
    error('Spatial channel-count mismatch: matrix has %d columns but live header has %d channels.', ...
        size(Spatial.CombinedMatrix, 2), nChannels);
end

%% ===== CHECK CHANNEL ORDER =====
% InputChannelNames are binding when present.
if isfield(Spatial, 'InputChannelNames') && ~isempty(Spatial.InputChannelNames)
    inputNames = local_cellstr(Spatial.InputChannelNames);
    if numel(inputNames) ~= nChannels || ~isequal(inputNames, channelNames)
        error('Spatial channel-order mismatch against corrected live header.');
    end
else
    Spatial.InputChannelNames = channelNames;
end

%% ===== CHECK FINGERPRINT AND CORRECTION STATE =====
% Structural header fingerprint excludes volatile NSamples and endpoints.
sourceFingerprint = local_source_fingerprint(Source);
spatialFingerprint = local_spatial_fingerprint(Spatial);
if local_is_legacy_nsamples_hash(spatialFingerprint)
    error(['Spatial metadata uses legacy NSamples-based LiveHeaderHash. ', ...
        'Regenerate matrix metadata with LiveHeaderFingerprint structural identity.']);
end
if ~isempty(spatialFingerprint) && ~isempty(sourceFingerprint) && ...
        ~strcmp(spatialFingerprint, sourceFingerprint)
    error('Spatial LiveHeaderFingerprint mismatch against current live header.');
elseif isempty(spatialFingerprint)
    spatialFingerprint = sourceFingerprint;
end
Spatial.LiveHeaderFingerprint = spatialFingerprint;
Spatial.LiveHeaderHash = spatialFingerprint;
if isfield(Source, 'HeaderFingerprintVersion')
    Spatial.LiveHeaderFingerprintVersion = Source.HeaderFingerprintVersion;
elseif ~isfield(Spatial, 'LiveHeaderFingerprintVersion')
    Spatial.LiveHeaderFingerprintVersion = NaN;
end

sourceCorrection = local_field(Source, 'CorrectionState', struct());
if isfield(Spatial, 'IsTechnicalFallback') && isequal(Spatial.IsTechnicalFallback, false)
    local_require_real_spatial_metadata(Spatial, sourceCorrection);
end
if isfield(Spatial, 'CorrectionState') && isstruct(Spatial.CorrectionState) && ...
        ~isempty(fieldnames(Spatial.CorrectionState)) && isstruct(sourceCorrection) && ...
        ~isempty(fieldnames(sourceCorrection))
    local_check_correction_state(Spatial.CorrectionState, sourceCorrection);
elseif ~isfield(Spatial, 'CorrectionState') || ~isstruct(Spatial.CorrectionState)
    Spatial.CorrectionState = sourceCorrection;
end

%% ===== NORMALIZE BOOLEAN FIELDS =====
% Saved reports expect scalar logical flags.
if ~isfield(Spatial, 'IsTechnicalFallback') || ~islogical(Spatial.IsTechnicalFallback) || ...
        ~isscalar(Spatial.IsTechnicalFallback)
    error('Spatial.IsTechnicalFallback must be a scalar logical.');
end
if ~isfield(Spatial, 'IsIPS') || ~islogical(Spatial.IsIPS) || ~isscalar(Spatial.IsIPS)
    error('Spatial.IsIPS must be a scalar logical.');
end

Spatial.ValidatedAgainstLiveHeader = true;

end

function local_require_real_spatial_metadata(Spatial, sourceCorrection)
% Precomputed/real spatial matrices must fail closed when metadata is absent.
if ~isfield(Spatial, 'IsIPS') || ~isequal(Spatial.IsIPS, true)
    error('Real/precomputed live spatial matrix must explicitly set IsIPS=true.');
end
if ~isfield(Spatial, 'InputChannelNames') || isempty(Spatial.InputChannelNames)
    error('Real/precomputed live spatial matrix is missing InputChannelNames metadata.');
end
if ~isfield(Spatial, 'CorrectionState') || ~isstruct(Spatial.CorrectionState) || ...
        isempty(fieldnames(Spatial.CorrectionState))
    error('Real/precomputed live spatial matrix is missing CorrectionState metadata.');
end
if ~isstruct(sourceCorrection) || isempty(fieldnames(sourceCorrection))
    error('Live source is missing CorrectionState metadata for real/precomputed spatial validation.');
end
requiredFields = {'AppliedChannelGains','AppliedMegRefCorrection', ...
    'RemovedBlockMean','AppliedProjector','RequiresMarcConfirmation','MarcConfirmed'};
for iField = 1:numel(requiredFields)
    fieldName = requiredFields{iField};
    if ~isfield(Spatial.CorrectionState, fieldName)
        error('Spatial CorrectionState missing required field %s.', fieldName);
    end
    if ~isfield(sourceCorrection, fieldName)
        error('Source CorrectionState missing required field %s.', fieldName);
    end
end
end

function local_check_correction_state(spatialState, sourceState)
% Compare only fields that can be compared safely as scalar values or text.
fields = intersect(fieldnames(spatialState), fieldnames(sourceState));
for iField = 1:numel(fields)
    fieldName = fields{iField};
    a = spatialState.(fieldName);
    b = sourceState.(fieldName);
    if strcmp(fieldName, 'Messages')
        continue;
    end
    if local_is_comparable(a) && local_is_comparable(b) && ~local_values_equal(a, b)
        error('Spatial correction-state mismatch for field %s.', fieldName);
    end
end
end

function tf = local_is_comparable(value)
% Allow conservative scalar/text comparisons.
tf = (islogical(value) && isscalar(value)) || ...
     (isnumeric(value) && isscalar(value) && isfinite(value)) || ...
     ischar(value) || (isstring(value) && isscalar(value));
end

function tf = local_values_equal(a, b)
% Compare scalar/text values.
if isnumeric(a) || islogical(a)
    tf = isequal(double(a), double(b));
else
    tf = strcmp(char(a), char(b));
end
end

function [channelNames, nChannels] = local_source_channel_names(Source)
% Prefer corrected live channel labels, then raw labels, then generated names.
channelNames = {};
if isstruct(Source) && isfield(Source, 'ChannelNamesAfterCorrection') && ...
        ~isempty(Source.ChannelNamesAfterCorrection)
    channelNames = local_cellstr(Source.ChannelNamesAfterCorrection);
elseif isstruct(Source) && isfield(Source, 'ChannelNames') && ~isempty(Source.ChannelNames)
    channelNames = local_cellstr(Source.ChannelNames);
end

if isempty(channelNames)
    nChannels = local_numeric_field(Source, 'NChannels', NaN);
    if ~isscalar(nChannels) || ~isfinite(nChannels) || nChannels < 1 || nChannels ~= round(nChannels)
        error('Cannot determine corrected live channel count for spatial revalidation.');
    end
    channelNames = local_default_channel_names(round(nChannels));
else
    nChannels = numel(channelNames);
end
end

function names = local_default_channel_names(nChannels)
% Generate deterministic channel labels when the source has no names.
names = cell(1, nChannels);
for iChannel = 1:nChannels
    names{iChannel} = sprintf('CH%03d', iChannel);
end
end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function value = local_text_field(S, fieldName, defaultValue)
% Read optional scalar text field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName)) && ...
        (ischar(S.(fieldName)) || isstring(S.(fieldName)))
    value = char(S.(fieldName));
end
end

function value = local_source_fingerprint(Source)
% Prefer canonical structural fingerprint, falling back to legacy alias.
value = local_text_field(Source, 'HeaderFingerprint', '');
if isempty(value)
    value = local_text_field(Source, 'HeaderHash', '');
end
end

function value = local_spatial_fingerprint(Spatial)
% Prefer canonical structural fingerprint, falling back to legacy alias.
value = local_text_field(Spatial, 'LiveHeaderFingerprint', '');
if isempty(value)
    value = local_text_field(Spatial, 'LiveHeaderHash', '');
end
end

function tf = local_is_legacy_nsamples_hash(value)
% Detect old volatile header hashes containing NSamples.
value = char(value);
tf = startsWith(value, 'fs_') && contains(value, '_nch_') && contains(value, '_ns_');
end

function value = local_numeric_field(S, fieldName, defaultValue)
% Read optional numeric scalar field.
value = defaultValue;
if isstruct(S) && isfield(S, fieldName) && isnumeric(S.(fieldName)) && isscalar(S.(fieldName))
    value = double(S.(fieldName));
end
end

function values = local_cellstr(values)
% Normalize text containers to a row cellstr.
if isempty(values)
    values = {};
elseif iscell(values)
    values = values(:)';
elseif isstring(values)
    values = cellstr(values(:))';
elseif ischar(values)
    values = cellstr(values);
    values = values(:)';
else
    values = {};
end
end
