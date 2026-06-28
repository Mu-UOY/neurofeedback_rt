function Results = nf_validate_band_detection(Data, Ref, Measures, RTConfig)
% NF_VALIDATE_BAND_DETECTION Summarize target-band power availability.
%
% USAGE:  Results = nf_validate_band_detection(Data, Ref, Measures, RTConfig)
%
% DESCRIPTION:
%     Reports whether the offline reference and streaming pipeline produced
%     valid target-band power windows, along with simple power summaries.

%% ===== INITIALIZE RESULTS =====
% Record the dataset and band context for the validation summary.
Results = struct();
Results.TargetBand = RTConfig.TargetBand;
Results.Fs = Data.Fs;
Results.NChannels = size(Data.X, 1);
Results.NSamples = size(Data.X, 2);
Results.RefValidWindows = nnz(Ref.IsValid);

%% ===== SUMMARIZE OFFLINE REFERENCE =====
% Reference power is the baseline for the streaming comparison.
if Results.RefValidWindows > 0
    Results.RefMeanPower = mean(Ref.Power(Ref.IsValid));
    Results.RefMedianPower = median(Ref.Power(Ref.IsValid));
else
    Results.RefMeanPower = NaN;
    Results.RefMedianPower = NaN;
end

%% ===== SUMMARIZE STREAMING MEASURES =====
% Measures may be empty if the real-time loop produced no valid chunks.
if isempty(Measures)
    Results.StreamValidWindows = 0;
    Results.StreamMeanPower = NaN;
else
    validMeasures = [Measures.IsValid] == true;
    Results.StreamValidWindows = nnz(validMeasures);
    if any(validMeasures)
        Results.StreamMeanPower = mean([Measures(validMeasures).Power]);
    else
        Results.StreamMeanPower = NaN;
    end
end

%% ===== ASSIGN STATUS =====
% Missing reference is a failure; missing stream after valid reference is a warning.
if Results.RefValidWindows == 0
    Results.Status = 'FAIL';
    Results.Message = 'Offline reference produced no valid windows.';
elseif Results.StreamValidWindows == 0
    Results.Status = 'WARN';
    Results.Message = 'Reference has valid windows, but streaming produced none.';
else
    Results.Status = 'PASS';
    Results.Message = 'Reference and streaming both produced valid target-band windows.';
end

end
