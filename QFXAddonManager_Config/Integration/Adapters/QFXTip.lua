local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("QFXTip") then return end
local Update = QFXAM.AdapterUtils.Update

Update("QFXTip", {
    description = function() return QFXAM.L.QFXTIP_DESCRIPTION end,
    openOptions = function()
        local api = rawget(_G, "QFXTipAPI")
        if api and api.OpenOptions then return api.OpenOptions() end
        error(QFXAM.L.OPEN_OPTIONS_FAILED)
    end,
})
