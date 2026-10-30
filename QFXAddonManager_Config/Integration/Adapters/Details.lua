local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("Details") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("Details", {
    nativeOptions = true,
    openOptions = QFXAM.AdapterUtils.NativeOptions(function()
        if type(_G.Details_OpenDefaultOptionsWindow) == "function" then
            _G.Details_OpenDefaultOptionsWindow()
            return
        end
        if _G.Details and type(_G.Details.OpenOptionsWindow) == "function" then
            _G.Details:OpenOptionsWindow()
            return
        end
        if TrySlash({ "DETAILS", "DETAILSSTATS" }, "options") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end),
})
