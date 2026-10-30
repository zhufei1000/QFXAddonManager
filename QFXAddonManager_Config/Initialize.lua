-- Runs once when the load-on-demand config addon is pulled in. Registers the
-- Config bundle with the shared toolbox runtime and applies the provider
-- branding to the factory singleton.
local _, ns = ...
local AM = ns.Manager
local R = ns.ToolboxRuntime

if R then
    local ok, err = R:Load("Config")
    if not ok and AM and AM.Print then
        AM.Print("QFXAddonManager_Config: " .. tostring(err))
    end
end

if AM and AM.Widgets and AM.Widgets.ApplyBrand then
    AM.Widgets.ApplyBrand()
end
