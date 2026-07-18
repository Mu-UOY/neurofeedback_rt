function test_step0_source_readiness_rejection()
% TEST_STEP0_SOURCE_READINESS_REJECTION Reject nonadvancing test transport.

RTConfig = nf_test_step0_config(tempname);
baseBuffer = RTConfig.Source.FieldTrip.TestBufferFcn;
RTConfig.Source.FieldTrip.TestBufferFcn = @local_no_advance;
local_assert_rejected(RTConfig);

malformedConfig = nf_test_step0_config(tempname);
malformedBase = malformedConfig.Source.FieldTrip.TestBufferFcn;
corruptNextHeader = false;
malformedConfig.Source.FieldTrip.TestBufferFcn = @local_malformed_advance;
local_assert_rejected(malformedConfig);

    function output = local_no_advance(command, arg, host, port)
        if strcmp(char(command), nf_modes().TestBufferCommand.Advance)
            hdr = baseBuffer('get_hdr', [], host, port);
            output = hdr.nsamples;
        else
            output = baseBuffer(command, arg, host, port);
        end
    end

    function output = local_malformed_advance(command, arg, host, port)
        if strcmp(char(command), nf_modes().TestBufferCommand.Advance)
            corruptNextHeader = true;
            output = malformedBase(command, arg, host, port);
        elseif corruptNextHeader && strcmp(char(command), 'get_hdr')
            corruptNextHeader = false;
            output = malformedBase(command, arg, host, port);
            output.nsamples = 'malformed';
        else
            output = malformedBase(command, arg, host, port);
        end
    end
end

function local_assert_rejected(RTConfig)
[Result, ~, Spatial, Logger] = nf_run_development_full_chain(RTConfig);
assert(Result.Started && Result.Partial && ~Result.Pass && ~Result.SourceReady);
assert(strcmp(Result.ErrorIdentifier, 'neurofeedback:developmentSourceNotReady'));
assert(isempty(Spatial) && isempty(Logger));
assert(exist(Result.PartialReportPath, 'file') == 2);
assert(exist(Result.TimelinePath, 'file') == 2);
timelineText = fileread(Result.TimelinePath);
assert(contains(timelineText, nf_modes().TimelineEvent.SessionStart));
assert(contains(timelineText, nf_modes().TimelineEvent.PrimaryError));
assert(~contains(timelineText, nf_modes().TimelineEvent.SpatialReady));
end
