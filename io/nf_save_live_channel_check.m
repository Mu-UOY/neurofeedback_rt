function Paths = nf_save_live_channel_check(Check, RTConfig, Session)
% NF_SAVE_LIVE_CHANNEL_CHECK Save a live channel/header check report.
%
% USAGE:  Paths = nf_save_live_channel_check(Check, RTConfig, Session)
%
% DESCRIPTION:
%     Writes MAT, TXT, and CSV reports into an already-created Session.
%     This helper never creates session folders.

%% ===== CHECK SESSION =====
% Session ownership belongs to nf_run_live_channel_check or the calling test.
if nargin < 3 || ~isstruct(Session) || ~isfield(Session, 'ReportsDir') || ...
        isempty(Session.ReportsDir)
    error('Session.ReportsDir is required; nf_save_live_channel_check does not create sessions.');
end
if exist(Session.ReportsDir, 'dir') ~= 7
    error('Session.ReportsDir does not exist: %s', Session.ReportsDir);
end

%% ===== RESOLVE OUTPUT PATHS =====
% Fixed filenames keep the formal check easy to find inside one session.
Paths = struct();
Paths.MatPath = fullfile(Session.ReportsDir, 'live_channel_check.mat');
Paths.TextPath = fullfile(Session.ReportsDir, 'live_channel_check.txt');
Paths.ChannelCsvPath = fullfile(Session.ReportsDir, 'live_channel_names.csv');

%% ===== SAVE MAT REPORT =====
% Store only Check and RTConfig, not raw chunks.
save(Paths.MatPath, 'Check', 'RTConfig');

%% ===== SAVE TEXT REPORT =====
% The text file is for MEG-room troubleshooting and audit review.
fid = fopen(Paths.TextPath, 'w');
if fid < 0
    error('Could not open live channel check text report: %s', Paths.TextPath);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Live channel/header check\n');
fprintf(fid, 'Status: %s\n', local_text(local_field(Check, 'Status', '')));
fprintf(fid, 'Pass: %s\n', local_bool(local_field(Check, 'Pass', false)));
fprintf(fid, 'Host: %s\n', local_text(local_field(Check, 'Host', '')));
fprintf(fid, 'Port: %s\n', local_text(local_field(Check, 'Port', [])));
fprintf(fid, 'Host setting origin: %s\n', local_setting_origin(Check, 'Host'));
fprintf(fid, 'Port setting origin: %s\n', local_setting_origin(Check, 'Port'));
fprintf(fid, 'Selected buffer.m path: %s\n', local_selected_buffer(Check));
fprintf(fid, 'All buffer.m candidates:\n');
local_print_cell(fid, local_buffer_candidates(Check));
fprintf(fid, 'MATLAB toolbox buffer shadowing detected: %s\n', ...
    local_bool(local_nested(Check, {'PathInfo','BufferLooksLikeMatlabToolbox'}, false)));
fprintf(fid, 'Buffer shadowing detected: %s\n', ...
    local_bool(local_nested(Check, {'PathInfo','BufferShadowingDetected'}, false)));
fprintf(fid, 'Fs: %s\n', local_text(local_field(Check, 'Fs', NaN)));
fprintf(fid, 'Expected Fs: %s\n', local_text(local_field(Check, 'ExpectedFs', NaN)));
fprintf(fid, 'Fs match: %s\n', local_bool(local_field(Check, 'FsMatches', false)));
fprintf(fid, 'NChannels: %s\n', local_text(local_field(Check, 'NChannels', NaN)));
fprintf(fid, 'Initial nsamples: %s\n', local_text(local_field(Check, 'InitialNSamples', NaN)));
fprintf(fid, 'Second nsamples: %s\n', local_text(local_field(Check, 'SecondNSamples', NaN)));
fprintf(fid, 'Sample count advanced: %s\n', local_bool(local_field(Check, 'SampleCountAdvanced', false)));
fprintf(fid, 'Acquisition block samples: %s\n', local_text(local_field(Check, 'AcquisitionBlockSamples', NaN)));
fprintf(fid, 'Acquisition block seconds: %s\n', local_text(local_field(Check, 'AcquisitionBlockSeconds', NaN)));
fprintf(fid, 'CTF res4 available: %s\n', local_bool(local_field(Check, 'HasCTFRes4', false)));
fprintf(fid, 'ChannelGains available: %s\n', local_bool(local_field(Check, 'HasChannelGains', false)));
fprintf(fid, 'MegRefCoef available: %s\n', local_bool(local_field(Check, 'HasMegRefCoef', false)));
fprintf(fid, 'Correction state: %s\n', local_struct_summary(local_field(Check, 'CorrectionState', struct())));
fprintf(fid, 'Channel mapping status: %s\n', local_channel_mapping_status(Check));
fprintf(fid, 'Ben indexing note: %s\n', local_text(local_field(Check, 'BenIndexingNote', '')));
fprintf(fid, 'Recommendation: %s\n', local_text(local_field(Check, 'Recommendation', '')));
fprintf(fid, 'Messages:\n');
local_print_cell(fid, local_field(Check, 'Messages', {}));

clear cleanupObj

%% ===== SAVE CHANNEL CSV =====
% Keep the CSV to labels only; no raw live data is saved here.
channelNames = local_cellstr(local_field(Check, 'ChannelNames', {}));
correctedNames = local_cellstr(local_field(Check, 'ChannelNamesAfterCorrection', {}));
nRows = max(numel(channelNames), numel(correctedNames));
channelNames = local_pad_cell(channelNames, nRows);
correctedNames = local_pad_cell(correctedNames, nRows);
Index = (1:nRows)'; %#ok<NASGU>
ChannelName = channelNames(:); %#ok<NASGU>
ChannelNameAfterCorrection = correctedNames(:); %#ok<NASGU>
T = table(Index, ChannelName, ChannelNameAfterCorrection);
writetable(T, Paths.ChannelCsvPath);

end

function value = local_field(S, fieldName, defaultValue)
% Read optional field.
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function value = local_nested(S, path, defaultValue)
% Read nested field.
value = defaultValue;
cursor = S;
for iPath = 1:numel(path)
    fieldName = path{iPath};
    if ~isstruct(cursor) || ~isfield(cursor, fieldName)
        return;
    end
    cursor = cursor.(fieldName);
end
value = cursor;
end

function textValue = local_text(value)
% Convert scalar values to text.
if isempty(value)
    textValue = '';
elseif isnumeric(value) && isscalar(value)
    textValue = num2str(value);
elseif islogical(value) && isscalar(value)
    textValue = local_bool(value);
elseif ischar(value)
    textValue = value;
elseif isstring(value)
    textValue = char(value);
else
    textValue = '<non-scalar>';
end
end

function textValue = local_bool(value)
% Format logical-like values.
textValue = 'false';
if islogical(value) && isscalar(value) && value
    textValue = 'true';
elseif isnumeric(value) && isscalar(value) && value ~= 0
    textValue = 'true';
end
end

function textValue = local_setting_origin(Check, fieldName)
% Read setting origin labels.
textValue = local_text(local_nested(Check, {'SettingOrigin', fieldName}, ''));
end

function textValue = local_selected_buffer(Check)
% Resolve selected buffer path from Check fields.
textValue = local_text(local_nested(Check, {'ResolvedConnection','SelectedBufferFunction'}, ''));
if isempty(textValue)
    textValue = local_text(local_nested(Check, {'PathInfo','SelectedBufferPath'}, ''));
end
end

function values = local_buffer_candidates(Check)
% Resolve all buffer candidates from PathInfo/ResolvedConnection.
values = local_nested(Check, {'PathInfo','AllBufferPaths'}, {});
if isempty(values)
    values = local_nested(Check, {'ResolvedConnection','AllBufferCandidates'}, {});
end
values = local_cellstr(values);
end

function local_print_cell(fid, values)
% Print a cell array as indented lines.
values = local_cellstr(values);
if isempty(values)
    fprintf(fid, '  <none>\n');
    return;
end
for iValue = 1:numel(values)
    fprintf(fid, '  %s\n', values{iValue});
end
end

function textValue = local_struct_summary(S)
% Build a compact one-line summary for small audit structs.
if ~isstruct(S) || isempty(S)
    textValue = '';
    return;
end
fields = fieldnames(S);
parts = cell(1, numel(fields));
for iField = 1:numel(fields)
    parts{iField} = [fields{iField} '=' local_text(S.(fields{iField}))];
end
textValue = strjoin(parts, '; ');
end

function textValue = local_channel_mapping_status(Check)
% Summarize channel name preservation/correction.
rawNames = local_cellstr(local_field(Check, 'ChannelNames', {}));
correctedNames = local_cellstr(local_field(Check, 'ChannelNamesAfterCorrection', {}));
if isempty(rawNames)
    textValue = 'missing_channel_names';
elseif isequal(rawNames, correctedNames)
    textValue = 'unchanged';
else
    textValue = 'changed_after_correction';
end
end

function values = local_cellstr(values)
% Normalize text containers to cellstr row.
if isempty(values)
    values = {};
elseif iscell(values)
    values = values(:)';
elseif isstring(values)
    values = cellstr(values(:))';
elseif ischar(values)
    values = cellstr(values);
    values = values(:)';
else
    values = {};
end
end

function values = local_pad_cell(values, nRows)
% Pad a cellstr to requested length.
values = values(:)';
while numel(values) < nRows
    values{end+1} = '';
end
end
