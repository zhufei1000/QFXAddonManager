local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("SimpleItemLevel") then return end

A.Register("SimpleItemLevel", {
    title = "SimpleItemLevel", category = "equipment", key = "simpleitemlevel",
    sourceURL = "https://www.curseforge.com/wow/addons/simple-item-level",
    nativeOptions = true,
    openOptions = A.NativeSlash("/simpleilvl", ""),
})
