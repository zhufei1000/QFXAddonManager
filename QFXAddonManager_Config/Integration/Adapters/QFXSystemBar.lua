local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("QFXSystemBar") then return end
local Update = QFXAM.AdapterUtils.Update

Update("QFXSystemBar", {
    nativeOptions = true,
    description = function() return QFXAM.L.SYSTEMBAR_DESCRIPTION end,
    openOptions = function(key)
        local api = rawget(_G, "QFXSystemBarAPI")
        if api and type(api.OpenNativeOptions) == "function" then
            return api.OpenNativeOptions(key)
        end
        error(QFXAM.L.OPEN_OPTIONS_FAILED)
    end,
})
