local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Capping") then return end

A.Register("Capping", {
    title = "Capping", category = "raid", key = "capping",
    sourceURL = "https://www.curseforge.com/wow/addons/capping-bg-timers",
    nativeOptions = true,
    openOptions = A.NativeSlash("/capping", ""),
})
