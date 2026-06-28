function [Xf, Info] = nf_apply_offline_brainstorm_bandpass(X, RTConfig)
% NF_APPLY_OFFLINE_BRAINSTORM_BANDPASS Obtain a Brainstorm-style reference.
%
% USAGE:  [Xf, Info] = nf_apply_offline_brainstorm_bandpass(X, RTConfig)
%
% DESCRIPTION:
%     Loads or computes an offline Brainstorm-style filtered signal in the
%     same post-spatial signal space as X. Missing optional Brainstorm
%     dependencies return SKIPPED unless RequireForPass is true.

%% ===== CHECK INPUTS =====
% The comparison input is already projected into the target signal space.
if ~isnumeric(X) || ndims(X) ~= 2
    error('X must be a numeric [nSignals x nSamples] matrix.');
end

mode = local_get_mode(RTConfig);
requireForPass = local_require_for_pass(RTConfig);

%% ===== DISPATCH BY MODE =====
% Mode auto tries the configured offline reference sources in priority order.
switch mode
    case 'skip'
        [Xf, Info] = local_skip('Brainstorm offline comparison disabled.');

    case 'iir_self_test'
        [Xf, IIRInfo] = nf_apply_offline_iir_sos(X, RTConfig);
        Info = IIRInfo;
        Info.Status = 'OK';
        Info.Mode = 'iir_self_test';
        Info.Message = 'IIR/SOS self-test reference. Do not use for scientific Brainstorm claims.';

    case 'precomputed_filtered'
        [Xf, Info] = local_precomputed_filtered(X, RTConfig, requireForPass);

    case 'filter_spec'
        [Xf, Info] = local_filter_spec(X, RTConfig, requireForPass);

    case 'bst_function'
        [Xf, Info] = local_bst_function(X, RTConfig, requireForPass);

    case 'auto'
        if isfield(RTConfig.Brainstorm, 'OfflineFilteredPath') && ...
                ~isempty(RTConfig.Brainstorm.OfflineFilteredPath) && ...
                exist(RTConfig.Brainstorm.OfflineFilteredPath, 'file') ~= 0
            [Xf, Info] = local_precomputed_filtered(X, RTConfig, requireForPass);
        elseif isfield(RTConfig.Brainstorm, 'FilterSpecPath') && ...
                ~isempty(RTConfig.Brainstorm.FilterSpecPath) && ...
                exist(RTConfig.Brainstorm.FilterSpecPath, 'file') ~= 0
            [Xf, Info] = local_filter_spec(X, RTConfig, requireForPass);
        elseif local_bst_function_exists(RTConfig)
            [Xf, Info] = local_bst_function(X, RTConfig, requireForPass);
        else
            [Xf, Info] = local_missing_brainstorm(requireForPass);
        end

    otherwise
        error('Unknown Step 1 Brainstorm mode: %s', mode);
end

end

function mode = local_get_mode(RTConfig)
mode = 'auto';
if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'Brainstorm') && ...
        isfield(RTConfig.Validation.Step1.Brainstorm, 'Mode') && ...
        ~isempty(RTConfig.Validation.Step1.Brainstorm.Mode)
    mode = RTConfig.Validation.Step1.Brainstorm.Mode;
end
end

function tf = local_require_for_pass(RTConfig)
tf = false;
if isfield(RTConfig, 'Validation') && isfield(RTConfig.Validation, 'Step1') && ...
        isfield(RTConfig.Validation.Step1, 'Brainstorm') && ...
        isfield(RTConfig.Validation.Step1.Brainstorm, 'RequireForPass')
    tf = logical(RTConfig.Validation.Step1.Brainstorm.RequireForPass);
end
end

function [Xf, Info] = local_skip(message)
Xf = [];
Info = struct();
Info.Status = 'SKIPPED';
Info.Mode = 'skip';
Info.Message = message;
Info.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function [Xf, Info] = local_missing_brainstorm(requireForPass)
message = ['Brainstorm offline reference unavailable; set OfflineFilteredPath, ', ...
    'set FilterSpecPath, use iir_self_test, or set Brainstorm.Mode = skip.'];
if requireForPass
    error('%s', message);
end
[Xf, Info] = local_skip(message);
Info.Mode = 'auto';
end

function [Xf, Info] = local_precomputed_filtered(X, RTConfig, requireForPass)
path = '';
if isfield(RTConfig.Brainstorm, 'OfflineFilteredPath')
    path = RTConfig.Brainstorm.OfflineFilteredPath;
end
if isempty(path) || exist(path, 'file') == 0
    message = 'Brainstorm precomputed filtered file is unavailable.';
    if requireForPass
        error('%s', message);
    end
    [Xf, Info] = local_skip(message);
    Info.Mode = 'precomputed_filtered';
    return;
end

variableName = 'XBrainstorm';
if isfield(RTConfig.Brainstorm, 'OfflineFilteredVariable') && ~isempty(RTConfig.Brainstorm.OfflineFilteredVariable)
    variableName = RTConfig.Brainstorm.OfflineFilteredVariable;
end

loaded = load(path);
if ~isfield(loaded, variableName)
    error('Precomputed Brainstorm file does not contain variable "%s".', variableName);
end
Xloaded = loaded.(variableName);
if isstruct(Xloaded) && isfield(Xloaded, 'X')
    Xloaded = Xloaded.X;
end
if ~isnumeric(Xloaded) || ~isequal(size(Xloaded), size(X))
    error(['Precomputed Brainstorm signal must be numeric and match post-spatial size [%d x %d]. ', ...
        'Raw-channel filtered data should be projected before saving.'], size(X, 1), size(X, 2));
end

Xf = Xloaded;
Info = struct();
Info.Status = 'OK';
Info.Mode = 'precomputed_filtered';
Info.Path = path;
Info.Variable = variableName;
Info.Message = 'Loaded precomputed Brainstorm-style filtered signal.';
Info.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function [Xf, Info] = local_filter_spec(X, RTConfig, requireForPass)
path = '';
if isfield(RTConfig.Brainstorm, 'FilterSpecPath')
    path = RTConfig.Brainstorm.FilterSpecPath;
end
if isempty(path) || exist(path, 'file') == 0
    message = 'Brainstorm filter spec file is unavailable.';
    if requireForPass
        error('%s', message);
    end
    [Xf, Info] = local_skip(message);
    Info.Mode = 'filter_spec';
    return;
end

loaded = load(path);
if isfield(loaded, 'FiltSpec')
    spec = loaded.FiltSpec;
elseif isfield(loaded, 'FilterSpec')
    spec = loaded.FilterSpec;
elseif isfield(loaded, 'b')
    spec = struct();
    spec.b = loaded.b;
    if isfield(loaded, 'a')
        spec.a = loaded.a;
    else
        spec.a = 1;
    end
else
    error('Filter spec file must contain FiltSpec, FilterSpec, or b/a variables.');
end

b = double(spec.b(:)');
if isfield(spec, 'a') && ~isempty(spec.a)
    a = double(spec.a(:)');
else
    a = 1;
end

Xf = zeros(size(X));
for iSignal = 1:size(X, 1)
    zi = zeros(max(numel(a), numel(b)) - 1, 1);
    [Xf(iSignal, :), ~] = filter(b, a, X(iSignal, :), zi);
end

delay = NaN;
if max(abs(b - fliplr(b))) <= 1e-10
    delay = (length(b) - 1) / 2;
else
    warning('Brainstorm filter spec coefficients are not symmetric; analytic delay is not reported.');
end

Info = struct();
Info.Status = 'OK';
Info.Mode = 'filter_spec';
Info.Path = path;
Info.b = b;
Info.a = a;
Info.AnalyticGroupDelaySamples = delay;
Info.Message = 'Applied Brainstorm filter spec causally with filter().';
Info.CreatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function [Xf, Info] = local_bst_function(X, RTConfig, requireForPass) %#ok<INUSD>
functionName = 'bst_bandpass_hfilter';

if isfield(RTConfig, 'Brainstorm') && ...
        isfield(RTConfig.Brainstorm, 'OfflineBandpassFunction') && ...
        ~isempty(RTConfig.Brainstorm.OfflineBandpassFunction)
    functionName = RTConfig.Brainstorm.OfflineBandpassFunction;
end

message = ['bst_function mode is not wired because ', functionName, ...
           ' signature has not been manually verified in this repository. ', ...
           'Provide a precomputed filtered file, a filter spec, or wire the ', ...
           'Brainstorm function call manually after inspecting the local file.'];

if requireForPass
    error('%s', message);
end

[Xf, Info] = local_skip(message);
Info.Mode = 'bst_function';
Info.FunctionName = functionName;
end

function tf = local_bst_function_exists(RTConfig)
functionName = 'bst_bandpass_hfilter';
if isfield(RTConfig.Brainstorm, 'OfflineBandpassFunction') && ~isempty(RTConfig.Brainstorm.OfflineBandpassFunction)
    functionName = RTConfig.Brainstorm.OfflineBandpassFunction;
end
tf = exist(functionName, 'file') ~= 0;
end
