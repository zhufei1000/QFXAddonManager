local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("QFXfocus") then return end
local Update = QFXAM.AdapterUtils.Update

Update("QFXfocus", {
    description = function() return QFXAM.L.QFXFOCUS_DESCRIPTION end,
    openOptions = function()
        local api = rawget(_G, "QFXfocusAPI")
        if api and api.OpenNativeConfig then return api.OpenNativeConfig() end
        if api and api.OpenOptions then
            return QFXAM.AdapterUtils.WithoutManagerOptions(function() return api.OpenOptions() end)
        end
        error(QFXAM.L.OPEN_OPTIONS_FAILED)
    end,
})
