local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("QFXTip") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("QFXTip", {
    description = function() return QFXAM.L.QFXTIP_DESCRIPTION end,
    embeddedSettings = function(context)
        local api = rawget(_G, "QFXTipAPI")
        if api and api.GetSettingsDefinition then return api.GetSettingsDefinition(context) end
    end,
    openOptions = function() QFXAM.AdapterUtils.OpenEmbeddedSettings("QFXTip") end,
})
