function Filter = nf_rt_filter_init(RTConfig, NSignals)
% NF_RT_FILTER_INIT Initialize streaming filter coefficients and state.
%
% USAGE:  Filter = nf_rt_filter_init(RTConfig, NSignals)
%
% DESCRIPTION:
%     Builds the filter coefficient/state struct used by streaming chunks,
%     including passthrough, Butterworth SOS, or Brainstorm FIR modes, plus
%     warmup and delay-correction metadata.

%% ===== CHECK SIGNAL COUNT =====
% Filter state is allocated per projected signal.
if ~isscalar(NSignals) || NSignals <= 0 || NSignals ~= round(NSignals)
    error('NSignals must be a positive integer scalar.');
end

%% ===== INITIALIZE FILTER STRUCT =====
% Filter.Type is copied from the validated RTConfig.
Filter = struct();
Filter.Type = RTConfig.Filter.Type;
Filter.NSignals = NSignals;

%% ===== BUILD FILTER IMPLEMENTATION =====
% Each branch initializes coefficients, state, delay, and discard metadata.
switch Filter.Type
    case 'none'
        % Passthrough filtering has no state and no delay.
        Filter.b = 1;
        Filter.a = 1;
        Filter.zi = zeros(0, NSignals);
        Filter.AnalyticGroupDelaySamples = 0;
        Filter.EmpiricalDelaySamples = NaN;
        Filter.DelayCorrectionUsed = 0;
        Filter.DiscardInitialSamples = local_discard_samples(RTConfig, 0);

    case 'iir_sos'
        % Butterworth SOS mode depends on Signal Processing Toolbox helpers.
        if exist('sosfilt', 'file') == 0 && exist('sosfilt', 'builtin') == 0
            error('Filter.Type = iir_sos requires sosfilt.');
        end
        if exist('butter', 'file') == 0 && exist('butter', 'builtin') == 0
            error('Filter.Type = iir_sos requires butter.');
        end

        % Normalize the target band to Nyquist before designing the filter.
        Wn = RTConfig.TargetBand ./ (RTConfig.Fs / 2);
        try
            [sos, g] = butter(RTConfig.Filter.Order, Wn, 'bandpass', 'sos');
        catch ME
            % Older MATLAB versions may need z/p/k design followed by zp2sos.
            if exist('zp2sos', 'file') == 0 && exist('zp2sos', 'builtin') == 0
                error('Could not design SOS Butterworth filter: %s', ME.message);
            end
            [z, p, k] = butter(RTConfig.Filter.Order, Wn, 'bandpass');
            [sos, g] = zp2sos(z, p, k);
        end

        if ~isscalar(g)
            error('Expected scalar SOS gain g. Per-section gains are not supported in this first version.');
        end

        % Store SOS state as [section x delay-state x signal].
        Filter.SOS = sos;
        Filter.G = g;
        Filter.AnalyticGroupDelaySamples = NaN;
        Filter.EmpiricalDelaySamples = NaN;
        Filter.DelayCorrectionUsed = local_delay_correction(RTConfig, 0);
        Filter.DiscardInitialSamples = local_discard_samples( ...
            RTConfig, max(RTConfig.Fs, RTConfig.PowerWindowSamples));
        Filter.zi = zeros(size(sos, 1), 2, NSignals);

    case 'brainstorm_fir'
        % Brainstorm mode loads or generates FIR coefficients.
        FiltSpec = local_load_brainstorm_filt_spec(RTConfig);
        Filter.b = double(FiltSpec.b(:)');
        if isfield(FiltSpec, 'a') && ~isempty(FiltSpec.a)
            Filter.a = double(FiltSpec.a(:)');
        else
            Filter.a = 1;
        end

        if max(abs(Filter.b - fliplr(Filter.b))) > 1e-10
            warning('FIR coefficients are not symmetric; analytic group delay may be invalid.');
        end

        % Linear-phase FIR group delay is half the filter order.
        Filter.AnalyticGroupDelaySamples = (length(Filter.b) - 1) / 2;
        Filter.EmpiricalDelaySamples = NaN;
        Filter.DelayCorrectionUsed = local_delay_correction(RTConfig, Filter.AnalyticGroupDelaySamples);
        Filter.DiscardInitialSamples = local_discard_samples( ...
            RTConfig, ceil(3 * Filter.AnalyticGroupDelaySamples));
        Filter.zi = zeros(max(length(Filter.a), length(Filter.b)) - 1, NSignals);
        Filter.FiltSpec = FiltSpec;

    otherwise
        error('Unknown filter type: %s', Filter.Type);
end

%% ===== INITIALIZE RUNTIME FILTER COUNTERS =====
% WarmupComplete gates power estimates until enough samples are processed.
Filter.WarmupComplete = Filter.DiscardInitialSamples == 0;
Filter.SamplesProcessed = 0;

end

function discard = local_discard_samples(RTConfig, defaultValue)
% Read or default the number of initial samples excluded from power estimates.
if isfield(RTConfig.Filter, 'DiscardInitialSamples') && ~isempty(RTConfig.Filter.DiscardInitialSamples)
    discard = RTConfig.Filter.DiscardInitialSamples;
else
    discard = defaultValue;
end
discard = max(0, ceil(discard));
end

function delay = local_delay_correction(RTConfig, defaultValue)
% Read or default the delay correction used for neural-time reporting.
delay = defaultValue;
if isfield(RTConfig.Filter, 'DelayCorrectionUsed') && ...
        ~isempty(RTConfig.Filter.DelayCorrectionUsed) && isfinite(RTConfig.Filter.DelayCorrectionUsed)
    delay = RTConfig.Filter.DelayCorrectionUsed;
end
end

function FiltSpec = local_load_brainstorm_filt_spec(RTConfig)
% Load Brainstorm FIR coefficients from disk.
FiltSpec = [];

if isfield(RTConfig.Brainstorm, 'FilterSpecPath') && ~isempty(RTConfig.Brainstorm.FilterSpecPath)
    % Saved specs avoid needing Brainstorm on the path at runtime.
    loaded = load(RTConfig.Brainstorm.FilterSpecPath);
    if isfield(loaded, 'FiltSpec')
        FiltSpec = loaded.FiltSpec;
    elseif isfield(loaded, 'FilterSpec')
        FiltSpec = loaded.FilterSpec;
    elseif isfield(loaded, 'b')
        FiltSpec = struct();
        FiltSpec.b = loaded.b;
        if isfield(loaded, 'a')
            FiltSpec.a = loaded.a;
        else
            FiltSpec.a = 1;
        end
    else
        error('Brainstorm FilterSpecPath must contain FiltSpec, FilterSpec, or b/a variables.');
    end
else
    error(['Filter.Type = brainstorm_fir requires RTConfig.Brainstorm.FilterSpecPath. ', ...
        'Direct Brainstorm function calls are not wired until the local function signature is manually verified.']);
end

% The first-version FIR path requires numerator coefficients.
if ~isfield(FiltSpec, 'b') || isempty(FiltSpec.b)
    error('Brainstorm filter spec must contain numerator coefficients in field b.');
end

% Default denominator to one for FIR specs.
if ~isfield(FiltSpec, 'a') || isempty(FiltSpec.a)
    FiltSpec.a = 1;
end

end
