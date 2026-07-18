function test_step0_development_label_enforcement()
% TEST_STEP0_DEVELOPMENT_LABEL_ENFORCEMENT Reject production claims and fallback gate.

RTConfig = nf_test_step0_config(tempname);
RTConfig.Session.ProductionEquivalent = true;
didError = false;
try
    nf_finalize_config(RTConfig);
catch
    didError = true;
end
assert(didError);

RTConfig = nf_test_step0_config(tempname);
Source = nf_source_init(nf_modes().Source.LiveFieldTrip, [], RTConfig);
Spatial = nf_prepare_live_combined_matrix(Source, RTConfig);
assert(Spatial.IsTechnicalFallback && ~Spatial.IsIPS);
assert(~RTConfig.Session.ProductionEquivalent);
end
