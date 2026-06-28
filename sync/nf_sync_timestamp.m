function Measure = nf_sync_timestamp(Measure, chunk, RT, RTConfig) %#ok<INUSD>
% NF_SYNC_TIMESTAMP Attach acquisition and neural-window timing metadata.
%
% USAGE:  Measure = nf_sync_timestamp(Measure, chunk, RT, RTConfig)
%
% DESCRIPTION:
%     Converts corrected sample indices to neural-window time, preserves the
%     acquisition timestamp when the source provided one, and leaves display
%     timing unset for later feedback presentation code.

%% ===== COMPUTE NEURAL TIME =====
% Measure.Time intentionally follows the delay-corrected neural window.
Measure.NeuralWindowTime = Measure.CorrectedWindowCenterSample ./ RTConfig.Fs;
Measure.Time = Measure.NeuralWindowTime;

%% ===== COPY ACQUISITION TIME =====
% Simulated sources may not have hardware timestamps.
if isfield(chunk, 'Timestamp') && isnumeric(chunk.Timestamp) && isscalar(chunk.Timestamp) && isfinite(chunk.Timestamp)
    Measure.AcquisitionTime = chunk.Timestamp;
else
    Measure.AcquisitionTime = NaN;
end

%% ===== INITIALIZE DISPLAY TIME =====
% Feedback display timing is not assigned in this first-version pipeline.
Measure.FeedbackDisplayTime = NaN;

end
