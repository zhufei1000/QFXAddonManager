local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("DBM-Core") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("DBM-Core", {
    nativeOptions = true,
    openOptions = QFXAM.AdapterUtils.NativeOptions(function()
        if _G.DBM and type(_G.DBM.LoadGUI) == "function" then
            _G.DBM:LoadGUI()
            return
        end
        if TrySlash({ "DEADLYBOSSMODS", "DBM" }, "") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end),
})
