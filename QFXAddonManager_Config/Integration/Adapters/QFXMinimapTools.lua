local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXMinimapTools") then return end
local A = AM.AdapterUtils

A.Register("QFXMinimapTools", { category = "map", categories = {"ui"},
    openOptions = function()
        local open = rawget(_G, "QFXMinimapTools_ToggleOptions")
        if type(open) == "function" then return open() end
        error(AM.L.OPEN_OPTIONS_FAILED)
    end })
