local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("BetterFishing") then return end

A.Register("BetterFishing", {
    title = "BetterFishing", category = "tool", key = "betterfishing",
    sourceURL = "https://www.curseforge.com/wow/addons/better-fishing",
    nativeOptions = true,
    openOptions = A.NativeSlash("/betterfishing", ""),
})
