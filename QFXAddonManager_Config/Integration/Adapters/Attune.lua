local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Attune") then return end

A.Register("Attune", {
    title = "Attune", category = "map", key = "attune",
    sourceURL = "https://www.curseforge.com/wow/addons/attune",
    nativeOptions = true,
    openOptions = A.NativeCategory("Attune"),
})
