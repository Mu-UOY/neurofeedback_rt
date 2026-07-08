function test_project_root_helper()
% TEST_PROJECT_ROOT_HELPER Check project-root resolution.

%% ===== CHECK PROJECT ROOT =====
% The helper should point at the neurofeedback_rt checkout root.
root = nf_project_root();

assert(exist(root, 'dir') ~= 0, 'nf_project_root did not return a folder.');
assert(exist(fullfile(root, 'startup.m'), 'file') == 2, ...
    'Project root does not contain startup.m.');
assert(exist(fullfile(root, 'config', 'nf_default_config.m'), 'file') == 2, ...
    'Project root does not contain config/nf_default_config.m.');
assert(exist(fullfile(root, 'tests', 'run_all_tests.m'), 'file') == 2, ...
    'Project root does not contain tests/run_all_tests.m.');

end
