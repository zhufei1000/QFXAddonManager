local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("CraftSim") then return end

A.Register("CraftSim", {
    title = "CraftSim", category = "tool", key = "craftsim",
    sourceURL = "https://www.curseforge.com/wow/addons/craftsim",
    nativeOptions = true,
    openOptions = A.NativeSlash("/craftsim", ""),
})
