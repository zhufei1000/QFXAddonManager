local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("RaiderIO") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("RaiderIO", {
    nativeOptions = true,
    openOptions = QFXAM.AdapterUtils.NativeOptions(function()
        if TrySlash({ "RaiderIO", "RAIDERIO" }, "") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end),
})
