function [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig)
% NF_RT_PROCESS_CHUNK Thin orchestrator for one real-time processing chunk.
%
% USAGE:  [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig)
%
% DESCRIPTION:
%     Runs one chunk through validation, spatial projection, filtering,
%     buffering, power computation, Measure packaging, z-scoring, counters,
%     timing, and optional schema checks.

%% ===== START TIMING =====
% Measure wall-clock processing duration for runtime validation.
tStart = tic;

%% ===== PREPROCESS CHUNK =====
% Validate raw chunk metadata, apply spatial projection, then filter causally.
[chunk, RT] = nf_rt_check_chunk(chunk, RT, RTConfig);
[chunk, RT] = nf_rt_apply_spatial(chunk, RT, RTConfig);
[chunk, RT] = nf_rt_filter_apply(chunk, RT, RTConfig);

%% ===== UPDATE BUFFER =====
% Store filtered samples and extract the latest power window.
RT.Buffer = nf_buffer_append(RT.Buffer, chunk.Data, chunk.SampleIndex, chunk, RTConfig);
window = nf_buffer_getlast(RT.Buffer, RTConfig.PowerWindowSamples);

%% ===== COMPUTE MEASURE =====
% Power diagnostics are packaged into the canonical Measure schema.
[Power, PowerPerSignal, IsValid, Diagnostics] = nf_rt_compute_power(window, RT, RTConfig);
Measure = nf_rt_make_measure(Power, PowerPerSignal, IsValid, Diagnostics, chunk, RT, RTConfig);
[Measure, RT] = nf_rt_compute_zscore(Measure, RT, RTConfig);

%% ===== UPDATE SAMPLE COUNTERS =====
% Counters summarize processing progress and valid output count.
RT.SampleCounter.ChunkCount = RT.SampleCounter.ChunkCount + 1;
RT.SampleCounter.TotalReceived = RT.SampleCounter.TotalReceived + chunk.NSamples;
if Measure.IsValid
    RT.SampleCounter.TotalValid = RT.SampleCounter.TotalValid + 1;
end

%% ===== RECORD RUNTIME =====
% Store elapsed seconds for this chunk.
RT.Timing.ChunkProcessingTimes(end + 1) = toc(tStart);

%% ===== CHECK OUTPUT SCHEMAS =====
% Debug schema checks catch regressions while the pipeline is evolving.
if RTConfig.Debug.CheckMeasureSchema
    Measure = nf_measure_check_schema(Measure);
end
if RTConfig.Debug.CheckRTSchema
    RT = nf_rt_check_schema(RT);
end

end
