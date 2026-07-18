function names = nf_step0_provisional_reference_channel_names(RTConfig)
% NF_STEP0_PROVISIONAL_REFERENCE_CHANNEL_NAMES Build audit-only labels.
%
% DESCRIPTION:
%     These are not real CTF reference labels. Step 3 must replace them with
%     the ordered labels characterized from the actual FieldTrip header.

nReferences = RTConfig.DevelopmentSession.Input.ReferenceMEGChannelCount;
prefix = char(RTConfig.DevelopmentSession.Input.ReferenceLabelPrefix);
width = max(1, ceil(log10(double(nReferences) + 1)));
names = cell(1, nReferences);
for iReference = 1:nReferences
    names{iReference} = sprintf('%s_PROVISIONAL_%0*d', prefix, width, iReference);
end

end
