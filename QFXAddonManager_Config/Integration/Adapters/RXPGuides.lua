local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("RXPGuides") then return end

A.Register("RXPGuides", {
    title = "RXPGuides", category = "map", key = "rxpguides",
    sourceURL = "https://www.curseforge.com/wow/addons/restedxp-guide",
    nativeOptions = true,
    openOptions = A.NativeSlash("/rxp", ""),
})
