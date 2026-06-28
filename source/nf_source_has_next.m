function tf = nf_source_has_next(Source)
% NF_SOURCE_HAS_NEXT Return true while the source has another chunk.
%
% USAGE:  tf = nf_source_has_next(Source)
%
% DESCRIPTION:
%     Checks whether a source adapter has a valid cursor and whether that
%     cursor has not passed the configured end sample.

%% ===== CHECK SOURCE CURSOR FIELDS =====
% Missing cursor fields mean the source cannot produce more data.
if ~isfield(Source, 'CurrentSample') || ~isfield(Source, 'EndSample')
    tf = false;
    return;
end

%% ===== TEST CURSOR POSITION =====
% A source has another chunk while CurrentSample is within bounds.
tf = Source.CurrentSample <= Source.EndSample;

end
