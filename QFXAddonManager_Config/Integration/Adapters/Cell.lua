local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("Cell") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

Update("Cell", {
    openOptions = function()
        if _G.Cell and type(_G.Cell.OpenOptionsFrame) == "function" then
            _G.Cell:OpenOptionsFrame()
            return
        end
        if TrySlash({ "CELL" }, "options") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end,
})
