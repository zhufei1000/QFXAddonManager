local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Bagnon") then return end

A.Register("Bagnon", {
    title = "Bagnon", category = "equipment", key = "bagnon",
    sourceURL = "https://www.curseforge.com/wow/addons/bagnon",
    nativeOptions = true,
    openOptions = A.NativeSlash("/bagnon", "config"),
})
