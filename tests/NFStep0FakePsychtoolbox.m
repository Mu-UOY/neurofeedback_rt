classdef NFStep0FakePsychtoolbox < handle
    % NFSTEP0FAKEPSYCHTOOLBOX Isolated command-compatible headless display.

    properties
        LogicalTime = 0
        WindowRect
        ChunkSeconds
        MalformedFlipTimestamp = false
        MalformedFlipIndex = NaN
        MissedValue = 0
        MissedValues = []
        TimestampValues = []
        FlipCount = 0
        LastFlipWhen = NaN
        LastFrameOvalLineWidthPx = NaN
        DrawLineWidthsPx = []
        DrawLineHalfWidthsPx = []
    end

    methods
        function obj = NFStep0FakePsychtoolbox(windowRect, chunkSeconds)
            obj.WindowRect = windowRect;
            obj.ChunkSeconds = chunkSeconds;
        end

        function value = time(obj)
            value = obj.LogicalTime;
        end

        function varargout = screen(obj, command, varargin)
            switch char(command)
                case 'Screens'
                    varargout{1} = [0 1];
                case 'OpenWindow'
                    varargout{1} = 1;
                    if numel(varargin) >= 3 && ~isempty(varargin{3})
                        varargout{2} = varargin{3};
                    else
                        varargout{2} = obj.WindowRect;
                    end
                case 'Flip'
                    obj.FlipCount = obj.FlipCount + 1;
                    obj.LogicalTime = obj.LogicalTime + obj.ChunkSeconds;
                    obj.LastFlipWhen = varargin{2};
                    timestamp = obj.LogicalTime;
                    if ~isempty(obj.TimestampValues)
                        timestamp = local_sequence_value(obj.TimestampValues, ...
                            obj.FlipCount, timestamp);
                    end
                    flipTimestamp = timestamp;
                    if obj.MalformedFlipTimestamp || ...
                            obj.FlipCount == obj.MalformedFlipIndex
                        flipTimestamp = NaN;
                    end
                    missed = obj.MissedValue;
                    if ~isempty(obj.MissedValues)
                        missed = local_sequence_value(obj.MissedValues, ...
                            obj.FlipCount, missed);
                    end
                    values = {timestamp, timestamp, flipTimestamp, missed, 0};
                    varargout = values(1:nargout);
                case 'FrameOval'
                    obj.LastFrameOvalLineWidthPx = varargin{4};
                    varargout = cell(1, nargout);
                case 'DrawLine'
                    obj.DrawLineWidthsPx(end + 1) = varargin{7};
                    halfWidth = max(abs(varargin{5} - varargin{3}), ...
                        abs(varargin{6} - varargin{4})) ./ 2;
                    obj.DrawLineHalfWidthsPx(end + 1) = halfWidth;
                    varargout = cell(1, nargout);
                case {'FillRect','FillOval','Close'}
                    varargout = cell(1, nargout);
                otherwise
                    error('Unsupported fake Screen command: %s', char(command));
            end
        end
    end
end

function value = local_sequence_value(values, index, defaultValue)
% Return a configured per-flip value while preserving its original type.
value = defaultValue;
if iscell(values)
    if index <= numel(values)
        value = values{index};
    end
elseif index <= numel(values)
    value = values(index);
end
end
