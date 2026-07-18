function test_validation_alignment_uses_uncorrected_samples()
% TEST_VALIDATION_ALIGNMENT_USES_UNCORRECTED_SAMPLES Check direct alignment field.
%
% USAGE:  test_validation_alignment_uses_uncorrected_samples()
%
% DESCRIPTION:
%     Builds measures whose corrected centers are shuffled and confirms direct
%     validation aligns by uncorrected WindowCenterSample.

%% ===== CONFIGURE VALIDATION =====
% Defaults provide the validation thresholds used by the comparison helper.
RTConfig = nf_default_config();
RTConfig.Debug.Verbose = false;

%% ===== BUILD REFERENCE =====
% Reference powers match the uncorrected measure order.
Ref = struct();
Ref.SampleIndex = [100 200 300];
Ref.Power = [1 2 3];
Ref.IsValid = [true true true];

%% ===== BUILD STREAMING MEASURES =====
% Corrected centers are intentionally out of order.
Measures = repmat(nf_measure_empty(), 1, 3);
for i = 1:3
    Measures(i).IsValid = true;
    Measures(i).Power = i;
end
Measures(1).WindowCenterSample = 100;
Measures(2).WindowCenterSample = 200;
Measures(3).WindowCenterSample = 300;
Measures(1).CorrectedWindowCenterSample = 200;
Measures(2).CorrectedWindowCenterSample = 300;
Measures(3).CorrectedWindowCenterSample = 100;

%% ===== RUN COMPARISON =====
% Perfect correlation proves uncorrected centers were used.
Results = nf_validate_brainstorm_vs_streaming(Ref, Measures, RTConfig);

%% ===== CHECK ALIGNMENT FIELD =====
% The result should advertise and use WindowCenterSample.
assert(strcmp(Results.AlignmentSampleField, 'WindowCenterSample'), 'Validation used the wrong alignment field.');
assert(abs(Results.Correlation - 1) < 1e-12, 'Validation did not align by uncorrected WindowCenterSample.');

end
