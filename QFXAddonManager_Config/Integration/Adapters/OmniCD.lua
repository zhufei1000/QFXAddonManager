local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("OmniCD") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("OmniCD", {
    openOptions = function()
        if _G.OmniCD and type(_G.OmniCD.OpenOptionPanel) == "function" then
            _G.OmniCD:OpenOptionPanel()
            return
        end
        if TrySlash({ "OMNICD", "OC" }, "") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end,
})
