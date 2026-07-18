function test_logs_codex_hygiene()
% TEST_LOGS_CODEX_HYGIENE Enforce the repository's code-summary-only folder.

root = nf_project_root();
folder = fullfile(root, 'logs', 'codex');
entries = dir(folder);
entries = entries(~ismember({entries.name}, {'.','..'}));
assert(~any([entries.isdir]), 'logs/codex must not contain subdirectories.');

% This allowlist defines repository structure, not runtime behavior.
allowed = sort({'build_code_summary.py','code_summary.txt'});
actual = sort({entries.name});
assert(isequal(actual, allowed), ...
    'logs/codex must contain exactly build_code_summary.py and code_summary.txt.');

generatorPath = fullfile(folder, 'build_code_summary.py');
generatorText = fileread(generatorPath);
assert(contains(generatorText, 'MATLAB_PATTERN = "*.m"'));
assert(contains(generatorText, ...
    'EXCLUDED_TOP_LEVEL_DIRECTORIES = {".git", "dev-archive", "logs", "outputs"}'));
assert(contains(generatorText, '"--check"'));
assert(contains(generatorText, '"--check-file"'));

summaryText = fileread(fullfile(folder, 'code_summary.txt'));
headers = regexp(summaryText, '(?m)^FILE: ([^\r\n]+)$', 'tokens');
assert(~isempty(headers), 'The generated code summary has no MATLAB file entries.');
headers = cellfun(@(token) token{1}, headers, 'UniformOutput', false);
assert(~any(startsWith(headers, '.git/')));
assert(~any(startsWith(headers, 'dev-archive/')));
assert(~any(startsWith(headers, 'logs/')));
assert(~any(startsWith(headers, 'outputs/')));

python = local_python_command();
[status, output] = system(sprintf('%s %s --check', ...
    python, local_shell_quote(generatorPath)));
assert(status == 0 && contains(output, '[PASS] code summary matches'), ...
    'Fresh code-summary provenance check failed: %s', output);

tamperedPath = [tempname '.txt'];
cleanup = onCleanup(@() local_delete(tamperedPath)); %#ok<NASGU>
copyfile(fullfile(folder, 'code_summary.txt'), tamperedPath);
fid = fopen(tamperedPath, 'a');
assert(fid > 0, 'Could not create tampered summary fixture.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, '\nARBITRARY NON-CODE CONTENT\n');
clear fileCleanup
[status, ~] = system(sprintf('%s %s --check-file %s', ...
    python, local_shell_quote(generatorPath), local_shell_quote(tamperedPath)));
assert(status ~= 0, 'The generator accepted non-generator summary content.');
end

function command = local_python_command()
if ispc
    candidates = {'py -3','python','python3'};
else
    candidates = {'python3','python'};
end
command = '';
for iCandidate = 1:numel(candidates)
    [status, ~] = system([candidates{iCandidate} ' --version']);
    if status == 0
        command = candidates{iCandidate};
        return;
    end
end
error('No Python interpreter is available for code-summary verification.');
end

function value = local_shell_quote(pathValue)
value = ['"' strrep(char(pathValue), '"', '\"') '"'];
end

function local_delete(pathValue)
if exist(pathValue, 'file') == 2
    delete(pathValue);
end
end
