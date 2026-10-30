local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("QFXfocus") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("QFXfocus", {
    description = function() return QFXAM.L.QFXFOCUS_DESCRIPTION end,
    embeddedSettings = function(context)
        local api = rawget(_G, "QFXfocusAPI")
        if api and api.GetSettingsDefinition then return api.GetSettingsDefinition(context) end
    end,
    openOptions = function() QFXAM.AdapterUtils.OpenEmbeddedSettings("QFXfocus") end,
})
