local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("HomeBound") then return end

A.Register("HomeBound", {
    title = "HomeBound", category = "equipment", key = "homebound",
    sourceURL = "https://www.curseforge.com/wow/addons/home-bound",
    nativeOptions = true,
    openOptions = A.NativeCategory("Home Bound"),
})
