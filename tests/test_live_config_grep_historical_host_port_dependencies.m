function test_live_config_grep_historical_host_port_dependencies()
% TEST_LIVE_CONFIG_GREP_HISTORICAL_HOST_PORT_DEPENDENCIES Check stale literals.

%% ===== SEARCH RELEVANT CODE =====
% Construct targets without writing the historical literals into this test.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
targets = {['10.' '0.' '0.' '2'], sprintf('%d', 1900 + 72)};
folders = {'config','source','tests'};
thisFile = [mfilename '.m'];
hits = {};

for iFolder = 1:numel(folders)
    files = dir(fullfile(projectRoot, folders{iFolder}, '*.m'));
    for iFile = 1:numel(files)
        if strcmp(files(iFile).name, thisFile)
            continue;
        end
        filePath = fullfile(files(iFile).folder, files(iFile).name);
        text = fileread(filePath);
        for iTarget = 1:numel(targets)
            if contains(text, targets{iTarget})
                hits{end+1} = filePath; %#ok<AGROW>
            end
        end
    end
end

assert(isempty(hits), 'Historical host/port literal still referenced: %s', ...
    strjoin(unique(hits), ', '));

end
