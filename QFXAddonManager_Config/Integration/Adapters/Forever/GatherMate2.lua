local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("GatherMate2") then return end

A.Register("GatherMate2", {
    category = "map", sourceURL = "https://www.curseforge.com/wow/addons/gathermate2",
    nativeOptions = true,
    openOptions = A.NativeSlash("/gathermate"),
})
