function local_check_scalar_string(value, label)
% Validate scalar text values while allowing char and string.
if ~(ischar(value) || (isstring(value) && isscalar(value)))
    error('%s must be char or scalar string.', label);
end
end
