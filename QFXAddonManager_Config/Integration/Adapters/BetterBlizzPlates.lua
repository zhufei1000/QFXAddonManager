local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("BetterBlizzPlates") then return end

A.Register("BetterBlizzPlates", {
    title = "BetterBlizzPlates", category = "ui", key = "betterblizzplates",
    sourceURL = "https://www.curseforge.com/wow/addons/betterblizzplates",
    nativeOptions = true,
    openOptions = A.NativeSlash("/bbp", ""),
})
