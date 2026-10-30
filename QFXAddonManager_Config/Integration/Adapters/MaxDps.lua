local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("MaxDps") then return end

A.Register("MaxDps", {
    title = "MaxDps", category = "combat", key = "maxdps",
    sourceURL = "https://www.curseforge.com/wow/addons/maxdps-rotation-helper",
    nativeOptions = true,
    openOptions = A.NativeSlash("/maxdps", ""),
})
