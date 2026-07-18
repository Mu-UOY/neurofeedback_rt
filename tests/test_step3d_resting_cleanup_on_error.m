function test_step3d_resting_cleanup_on_error()
% TEST_STEP3D_RESTING_CLEANUP_ON_ERROR Check resting cleanup on RT error.

%% ===== PREPARE SHADOWED RT CORE =====
[RTConfig, tempRoot] = nf_test_live_self_test_config();
RTConfig.LiveResting.SavePartialEveryNMeasures = 1;
RTConfig.Logging.FlushEveryNMeasures = 1;
[shadowDir, cleanupShadow] = local_shadow_function('nf_rt_process_chunk', ...
    {'function [Measure, RT] = nf_rt_process_chunk(chunk, RT, RTConfig)', ...
     '%#ok<INUSD>', ...
     'error(''test:rt_error'', ''forced RT processing error'');', ...
     'end'});
cleanupObj = onCleanup(@() local_cleanup(tempRoot, shadowDir, cleanupShadow));

%% ===== RUN RESTING =====
[~, RestingResult] = nf_run_live_resting(RTConfig);

assert(RestingResult.Pass == false, 'Resting unexpectedly passed.');
assert(strcmp(RestingResult.StopReason, nf_modes().StopReason.Error), ...
    'RT error did not set error stop reason.');
assert(strcmp(RestingResult.ErrorIdentifier, 'test:rt_error'), ...
    'RT error identifier was not preserved.');
assert(RestingResult.SafetyClosed == true, 'Safety cleanup was not attempted.');
assert(RestingResult.LoggerClosed == true, 'Owned logger was not closed.');
assert(RestingResult.Partial == true, 'Resting crash was not marked partial.');
assert(~isempty(RestingResult.PartialLogPaths), 'Resting crash did not save partial log.');
assert(exist(RestingResult.PartialLogPaths{end}, 'file') == 2, 'Partial log file missing.');

clear cleanupObj
end

function [shadowDir, cleanupObj] = local_shadow_function(functionName, lines)
shadowDir = tempname();
mkdir(shadowDir);
fid = fopen(fullfile(shadowDir, [functionName '.m']), 'w');
assert(fid > 0, 'Could not create shadow function.');
for iLine = 1:numel(lines)
    fprintf(fid, '%s\n', lines{iLine});
end
fclose(fid);
addpath(shadowDir, '-begin');
clear(functionName);
cleanupObj = onCleanup(@() local_cleanup_shadow(shadowDir, functionName));
end

function local_cleanup(tempRoot, shadowDir, cleanupShadow)
clear cleanupShadow
if exist(shadowDir, 'dir')
    rmdir(shadowDir, 's');
end
if exist(tempRoot, 'dir')
    rmdir(tempRoot, 's');
end
end

function local_cleanup_shadow(shadowDir, functionName)
rmpath(shadowDir);
clear(functionName);
end
