local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("PetStatusAlert") then return end
local Update = QFXAM.AdapterUtils.Update

Update("PetStatusAlert", {
    description = function() return QFXAM.L.PSA_DESCRIPTION end,
    openOptions = function()
        local api = rawget(_G, "PetStatusAlert")
        if api and api.OpenOptionsFrame then return api.OpenOptionsFrame() end
        error(QFXAM.L.OPEN_OPTIONS_FAILED)
    end,
})
