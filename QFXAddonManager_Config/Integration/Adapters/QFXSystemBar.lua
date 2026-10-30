local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("QFXSystemBar") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("QFXSystemBar", {
    description = function() return QFXAM.L.SYSTEMBAR_DESCRIPTION end,
    embeddedSettings = function(context)
        local api = rawget(_G, "QFXSystemBarAPI")
        if api and api.GetSettingsDefinition then return api.GetSettingsDefinition(context) end
    end,
    openOptions = function() QFXAM.AdapterUtils.OpenEmbeddedSettings("QFXSystemBar") end,
})
