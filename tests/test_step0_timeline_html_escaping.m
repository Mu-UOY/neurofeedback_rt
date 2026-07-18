function test_step0_timeline_html_escaping()
% TEST_STEP0_TIMELINE_HTML_ESCAPING Verify report text cannot alter HTML.

RTConfig = nf_test_step0_config(tempname);
sessionDir = tempname; mkdir(sessionDir);
Timeline = nf_development_timeline_init(RTConfig, sessionDir);
Timeline = nf_development_timeline_append(Timeline, ...
    nf_modes().TimelineEvent.PrimaryError, nf_modes().Phase.Trial, ...
    NaN, NaN, '&<>"''', true);
textValue = fileread(Timeline.Path);
assert(contains(textValue, '&amp;&lt;&gt;&quot;&#39;'));
end
