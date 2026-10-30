-- Runs once when the bundle addon is pulled in: register the module files
-- with the shared runtime and execute the bundle.
local _, ns = ...
local AM = ns.Manager
local R = ns.ToolboxRuntime

if R then
    local ok, err = R:Load("ChatBar")
    if not ok and AM and AM.Print then
        AM.Print("QFXAddonManager_Toolbox_ChatBar: " .. tostring(err))
    end
end
