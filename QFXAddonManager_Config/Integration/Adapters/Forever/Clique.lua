local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Clique") then return end

A.Register("Clique", {
    category = "combat", sourceURL = "https://www.curseforge.com/wow/addons/clique",
    nativeOptions = true,
    openOptions = A.NativeSlash("/clique"),
})
