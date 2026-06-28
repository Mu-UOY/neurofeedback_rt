function Results = nf_validate_filter_runtime(processingTimes, RTConfig)
% NF_VALIDATE_FILTER_RUNTIME Check whether chunk processing is real-time feasible.
%
% USAGE:  Results = nf_validate_filter_runtime(processingTimes, RTConfig)
%
% DESCRIPTION:
%     Summarizes measured per-chunk processing times and compares the maximum
%     runtime to the chunk duration and configured warning threshold.

%% ===== INITIALIZE RESULTS =====
% Empty timing data is informative rather than a hard validation failure.
Results = struct();

if isempty(processingTimes)
    Results.Status = 'INFO';
    Results.Message = 'No processing times recorded.';
    return;
end

%% ===== COMPUTE CHUNK DURATION =====
% Real-time processing must complete before the next chunk arrives.
chunkDuration = RTConfig.ChunkSamples ./ RTConfig.Fs;

%% ===== SUMMARIZE RUNTIME =====
% Store absolute runtime and runtime-as-fraction-of-chunk metrics.
Results.MeanRuntimeSecs = mean(processingTimes);
Results.MaxRuntimeSecs = max(processingTimes);
Results.StdRuntimeSecs = std(processingTimes);
Results.MeanFraction = Results.MeanRuntimeSecs ./ chunkDuration;
Results.MaxFraction = Results.MaxRuntimeSecs ./ chunkDuration;

%% ===== ASSIGN STATUS =====
% More than one chunk duration cannot keep up in real time.
if Results.MaxFraction > 1
    Results.Status = 'FAIL';
elseif Results.MaxFraction > RTConfig.Validation.MaxRuntimeFraction
    Results.Status = 'WARN';
else
    Results.Status = 'PASS';
end

%% ===== PACKAGE MESSAGE =====
% Keep the validation summary concise.
Results.Message = sprintf('Max runtime %.4fs for %.4fs chunks.', ...
    Results.MaxRuntimeSecs, chunkDuration);

end
