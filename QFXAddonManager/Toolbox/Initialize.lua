local _, AM = ...
local R = AM.ToolboxRuntime
local ok, err = R:Load("Core")
if not ok then error("QFX builtin toolbox: " .. tostring(err)) end
