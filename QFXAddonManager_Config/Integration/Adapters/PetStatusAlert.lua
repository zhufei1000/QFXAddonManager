local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("PetStatusAlert") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("PetStatusAlert", {
    description = function() return QFXAM.L.PSA_DESCRIPTION end,
    embeddedSettings = function(context)
        local api = rawget(_G, "PetStatusAlert")
        if api and api.GetSettingsDefinition then return api.GetSettingsDefinition(context) end
    end,
    openOptions = function() QFXAM.AdapterUtils.OpenEmbeddedSettings("PetStatusAlert") end,
})
