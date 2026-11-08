local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXUnitframes") then return end
local A = AM.AdapterUtils

A.Register("QFXUnitframes", { category = "ui", categories = {"combat"},
    openOptions = function()
        local api = rawget(_G, "QFXUnitframesManagerAPI")
        if api and api.OpenNativeConfig then return api.OpenNativeConfig() end
        error(AM.L.OPEN_OPTIONS_FAILED)
    end })
