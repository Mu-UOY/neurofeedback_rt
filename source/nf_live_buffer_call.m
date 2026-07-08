function varargout = nf_live_buffer_call(RTConfig, command, arg)
% NF_LIVE_BUFFER_CALL Call the FieldTrip realtime buffer or a test hook.
%
% USAGE:  varargout = nf_live_buffer_call(RTConfig, command, arg)
%
% DESCRIPTION:
%     Centralizes FieldTrip buffer access so hardware-free tests can provide
%     RTConfig.Source.FieldTrip.TestBufferFcn while live code still calls the
%     selected FieldTrip buffer.m function.

%% ===== RESOLVE CONNECTION SETTINGS =====
% Host and port are editable config fields; this helper does not guess them.
host = RTConfig.Source.FieldTrip.Host;
port = RTConfig.Source.FieldTrip.Port;

%% ===== USE TEST HOOK WHEN CONFIGURED =====
% TestBufferFcn signature is fakeBuffer(command, arg, host, port).
if isfield(RTConfig.Source.FieldTrip, 'TestBufferFcn') && ...
        ~isempty(RTConfig.Source.FieldTrip.TestBufferFcn)
    [varargout{1:nargout}] = RTConfig.Source.FieldTrip.TestBufferFcn(command, arg, host, port);
    return;
end

%% ===== CALL FIELDTRIP BUFFER =====
% nf_live_add_fieldtrip_paths validates that this resolves to the intended
% realtime buffer.m before live source initialization reaches this point.
[varargout{1:nargout}] = buffer(command, arg, host, port);

end
