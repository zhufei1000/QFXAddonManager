local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Decursive") then return end

A.Register("Decursive", {
    title = "Decursive", category = "combat", key = "decursive",
    sourceURL = "https://www.curseforge.com/wow/addons/decursive",
    nativeOptions = true,
    openOptions = A.NativeSlash("/decursive", ""),
})
