function root = nf_project_root()
% NF_PROJECT_ROOT Return the neurofeedback_rt project root.

persistent cachedRoot
if isempty(cachedRoot)
    thisFile = mfilename('fullpath');
    configDir = fileparts(thisFile);
    cachedRoot = fileparts(configDir);
end
root = cachedRoot;

end
