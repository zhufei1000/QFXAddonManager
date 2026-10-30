local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("WeakAuras") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("WeakAuras", {
    openOptions = function()
        if _G.WeakAuras and type(_G.WeakAuras.OpenOptions) == "function" then
            _G.WeakAuras.OpenOptions()
            return
        end
        if TrySlash({ "WEAKAURAS", "WA" }, "") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end,
})
