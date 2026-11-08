local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("MapUtils") then return end

A.Register("MapUtils", {
    category = "map", sourceURL = "https://www.curseforge.com/wow/addons/maputils",
    nativeOptions = true,
    openOptions = A.NativeSlash("/maputils"),
})
