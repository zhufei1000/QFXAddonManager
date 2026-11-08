local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("InspectForEllesmereUI") then return end
local A = AM.AdapterUtils

-- The addon maintains all of its own settings; the manager only opens the
-- native settings window.
A.Register("InspectForEllesmereUI", { category = "equipment", categories = {"ui"},
    addons = {"InspectForEllesmereUI"},
    openOptions = function()
        local api = rawget(_G, "InspectForEllesmereUIManagerAPI")
        if api and api.OpenNativeSettings then return api.OpenNativeSettings() end
        error(AM.L.OPEN_OPTIONS_FAILED)
    end })
