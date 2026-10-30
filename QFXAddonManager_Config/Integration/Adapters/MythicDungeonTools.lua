local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("MythicDungeonTools") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("MythicDungeonTools", {
    openOptions = function()
        if TrySlash({ "MDT", "MYTHICDUNGEONTOOLS" }, "") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end,
})
