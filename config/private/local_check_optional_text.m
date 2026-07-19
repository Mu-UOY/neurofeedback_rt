function local_check_optional_text(value, label)
% Validate optional text fields used for editable live paths/settings.
if isempty(value)
    return;
end
local_check_scalar_string(value, label);
end
