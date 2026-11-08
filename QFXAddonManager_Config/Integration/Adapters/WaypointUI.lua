local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("WaypointUI") then return end
local A = AM.AdapterUtils

-- WaypointUI keeps its own settings window and database. The manager only
-- forwards the native entry point.
A.Update("WaypointUI", {
    openOptions = A.NativeOptions(function()
        local api = rawget(_G, "WaypointUIAPI")
        if api and api.OpenSettingsUI then return api.OpenSettingsUI() end
        return A.CallNativeSlash("/waypoint")
    end),
})
