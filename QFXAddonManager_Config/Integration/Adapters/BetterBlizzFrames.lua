local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("BetterBlizzFrames") then return end

A.Register("BetterBlizzFrames", {
    title = "BetterBlizzFrames", category = "ui", key = "betterblizzframes",
    sourceURL = "https://www.curseforge.com/wow/addons/betterblizzframes",
    nativeOptions = true,
    openOptions = A.NativeSlash("/bbf", ""),
})
