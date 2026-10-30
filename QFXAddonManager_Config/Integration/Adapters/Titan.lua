local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Titan") then return end

A.Register("Titan", {
    title = "Titan", category = "ui", key = "titan",
    sourceURL = "https://www.curseforge.com/wow/addons/titan-panel",
    nativeOptions = true,
    openOptions = A.NativeSlash("/titan", "gui"),
})
