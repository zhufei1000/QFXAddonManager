local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("Plater") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("Plater", {
    openOptions = function()
        if _G.Plater and type(_G.Plater.OpenOptionsPanel) == "function" then
            _G.Plater.OpenOptionsPanel()
            return
        end
        if TrySlash({ "PLATER" }, "options") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end,
})
